# catcode-ollama-cloud-docker-sbx

A custom [Docker Sandbox](https://docs.docker.com/ai/sandboxes/) template that securely and easily runs [Catalyst Code](https://code.catalystctl.com) (`catcode`) with [Ollama Cloud](https://ollama.com) as the LLM provider.

## Prerequisites

- [Docker Sandbox](https://docs.docker.com/ai/sandboxes/) installed
- An [Ollama Cloud](https://signin.ollama.com/) account

## Setup

#### 1. Store your Ollama Cloud API key (one-time)

Get your API key from [Ollama Cloud](https://ollama.com/settings/keys)
```shell
sbx secret set-custom -g --host ollama.com --host *.ollama.com --env OLLAMA_API_KEY
```
You'll be prompted to paste your API key interactively — the key never touches your shell history or command line.

#### 2. Allow sbx access to Ollama Cloud (one-time)
```shell
# Tip: The `sbx setup` defaults are sufficient for most setups
sbx setup
sbx policy allow network "ollama.com,*.ollama.com"
```

#### 3. Run the Agent

```shell
# Tip: Change Directory (cd) to the directory where you want to run the Agent prior to running the command below
sbx run shell --template warfront1catcodeocds/catcode-ollama-cloud-docker-sbx:latest
```

## Want to contribute or modify this template?
See [DEVELOPERS.md](DEVELOPERS.md).