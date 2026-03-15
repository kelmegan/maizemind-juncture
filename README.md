# Juncture

## Description

Juncture is a visual reasoning tool that transforms messy notes into structured argument graphs with AI-powered analysis. It creates an interactive visual map from your ideas, evaluates reasoning quality, and provides actionable feedback to strengthen your arguments.

Built with [Jac/Jaseci](https://www.jac-lang.org/) — full-stack (server walkers + client React components).

## Setup

### 1. Python environment

```bash
python -m venv .venv
source .venv/bin/activate
```

### 2. Install Jaseci

```bash
pip install jaseci
```

Verify with `jac --version`.

### 3. LLM setup

Juncture uses `by llm()` for AI-powered graph generation. The model is configured in `jac.toml`:

```toml
[plugins.byllm.model]
default_model = "ollama/minimax-m2.5:cloud"
verbose = true

[plugins.byllm.call_params]
temperature = 0.3
max_tokens = 1500
```

**Using MiniMax (current default):**

MiniMax M2.5 is a free cloud model accessed through Ollama's cloud routing. To set it up:

1. Install Ollama: https://ollama.com/download
2. Install litellm: `pip install litellm`
3. No API key needed — MiniMax cloud is free through Ollama

**Using other models:**

You can swap the model in `jac.toml` by changing `default_model`. Examples:

| Model | Config value | Requires |
|-------|-------------|----------|
| MiniMax (free) | `ollama/minimax-m2.5:cloud` | Ollama installed |
| Llama 3 (local) | `ollama/llama3` | `ollama pull llama3` |
| GPT-4o Mini | `openai/gpt-4o-mini` | `OPENAI_API_KEY` env var |
| Claude Sonnet | `anthropic/claude-sonnet-4-20250514` | `ANTHROPIC_API_KEY` env var |

Set API keys as environment variables:

```bash
export OPENAI_API_KEY="sk-..."
# or
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Using a custom OpenAI-compatible endpoint (e.g. self-hosted, reasoning models):**

If you're running a model through an OpenAI-compatible server, add `base_url`, `proxy`, and `api_key` to your `jac.toml`:

```toml
[plugins.byllm.model]
default_model = "openai/your-model-name"
base_url = "http://your-server:port/v1"
proxy = true
api_key = "your-key"
verbose = true

[plugins.byllm.call_params]
temperature = 0.3
max_tokens = 16384
```

Notes:
- Reasoning models that use tokens for internal thinking (e.g. o1, QwQ) need a higher `max_tokens` (16384+). The default 1500 will cause truncated responses.
- `proxy = true` is required when using `base_url` — without it, the base URL is ignored.
- The `extract_llm_text()` helper in `graph_generator.jac` handles both string and ChatCompletion response formats, so any OpenAI-compatible API should work.

### 4. Run

```bash
jac start main.jac
```

The app will be available at `http://localhost:8000/`.

To clear cached data and start fresh:

```bash
rm -rf .jac && jac start main.jac
```

## Architecture

- `main.jac` — Entry point, imports all walkers, renders client app
- `src/graph_generator.jac` — LLM pipeline (2 calls: parse notes into graph, analyze weaknesses)
- `walkers/` — Server-side walkers for graph generation, revision, user/session management
- `screens/` — Client `.cl.jac` React screens (Welcome, Generate, Review, Revise, Export, Profile)
- `components/` — Reusable UI components (ArgumentGraphView, Button, Card, etc.)
- `graph/` — Node schema definitions (AppContext, User, Session, ArgumentGraph)

## Team

**MaizeMind (Group 9):**

Megan Kelly, Maya Hillegonds, Justin Cha, Kaelyn Lin, Lyra Sharma
