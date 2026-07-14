# ===========================================================================
# Stage 1 — Build catcode from source
# ===========================================================================
FROM rust:1.86-bookworm AS builder

ARG CATCODE_TAG=d49e25f
ARG GO_VERSION=1.25.0

# Install Go from the official tarball (Go is not in the rust image).
ADD https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz /tmp/go.tar.gz
RUN tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Clone catcode at the requested tag.
WORKDIR /build
RUN git clone --depth 1 --branch ${CATCODE_TAG} \
      https://github.com/catalystctl/catcode.git /build/catcode

# Switch reqwest from rustls-tls (compiled-in webpki-roots) to
# rustls-tls-native-roots so it reads the system trust store at runtime.
RUN sed -i 's/"rustls-tls"/"rustls-tls-native-roots"/' /build/catcode/core/Cargo.toml

# Build the Rust core, then the Go TUI (which embeds the core binary).
# release-linux.sh does:  cargo build → cp core/target/release/core tui/embed/catcode-core
#                       → cd tui && CGO_ENABLED=0 go build -tags embed_core …
RUN cd /build/catcode && \
    cargo build --release --manifest-path core/Cargo.toml && \
    cp core/target/release/core tui/embed/catcode-core && \
    cd tui && \
    CGO_ENABLED=0 go build -trimpath -tags embed_core \
      -ldflags "-s -w -X main.coreVersion=${CATCODE_TAG}" \
      -o /build/catcode-bin .

# ===========================================================================
# Stage 2 — Runtime image
# ===========================================================================
FROM docker/sandbox-templates:shell

USER root

# Install the catcode binary (built in stage 1).
COPY --from=builder /build/catcode-bin /usr/local/bin/catcode
RUN chmod +x /usr/local/bin/catcode \
 && /usr/local/bin/catcode --version </dev/null >/dev/null 2>&1 || true

RUN mkdir -p /home/agent/.config/catalyst-code \
 && printf '{\n  "providers": [\n    {\n      "name": "ollama-cloud",\n      "kind": "openai",\n      "base_url": "https://ollama.com/v1",\n      "api_key_env": "OLLAMA_API_KEY"\n    }\n  ],\n  "activeProvider": "ollama-cloud",\n  "model": "glm-5.1"\n}\n' > /home/agent/.config/catalyst-code/config.json \
 && chmod 600 /home/agent/.config/catalyst-code/config.json \
 && chown -R agent:agent /home/agent/.config

# Fallback placeholder.
ENV OLLAMA_API_KEY="proxy-managed"

# Auto-launch catcode when an interactive shell starts.
# Guards prevent re-launching in nested/non-interactive shells.
# Set CATCODE_NO_AUTOSTART=1 to skip auto-launch and get a plain shell.
RUN printf '\n# Auto-launch catcode on interactive login\nif [ -z "$CATCODE_AUTOSTARTED" ] && [ -z "$CATCODE_NO_AUTOSTART" ] && [ -t 1 ]; then\n  export CATCODE_AUTOSTARTED=1\n  catcode\nfi\n' >> /home/agent/.bashrc \
 && printf '\n# Ensure interactive login shells source .bashrc (auto-launch catcode)\nif [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then\n  . "$HOME/.bashrc"\nfi\n' >> /home/agent/.bash_profile \
 && chown agent:agent /home/agent/.bashrc /home/agent/.bash_profile

USER agent