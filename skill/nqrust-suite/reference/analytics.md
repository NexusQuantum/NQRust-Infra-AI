# Reference — NexusQuantum Analytics

> **This is the OFFLINE FALLBACK.** The primary source of truth is the live docs at
> **https://docs.analytics.nexusquantum.id** (e.g. `/get-started/installation`, `/get-started/quickstart`,
> `/accounts/oauth`). Fetch those first (web fetch); use this file when offline/airgapped or for
> the exact compose/env facts below. See SKILL.md → "Documentation sources".

NL-driven analytics platform (query your data in plain language) deployed as a
Docker Compose stack via the `nqrust-analytics` TUI installer.
Source: github.com/NexusQuantum/installer-NQRust-Analytics

## Services (docker-compose)
| Service | Image | Default port | Role |
|---|---|---|---|
| `analytics-ui` | ghcr.io/nexusquantum/analytics-ui | **3000** | Web UI + user management (the thing users open) |
| `analytics-engine` | ghcr.io/nexusquantum/analytics-engine | 8080 | Core query engine |
| `ibis-server` | ghcr.io/nexusquantum/analytics-engine-ibis | 8000 | Python data-transform layer |
| `analytics-service` | ghcr.io/nexusquantum/analytics-service | 5555 | AI analytics + Document RAG |
| `qdrant` | qdrant/qdrant:v1.11.0 | 6333/6334 (internal) | Vector DB for embeddings |
| `northwind-db` | postgres:15 | 5435 (`POSTGRES_PORT`) | Demo DB **and** the `analytics` app DB |
| `analytics-db-init` | postgres:15 | — (one-shot) | Idempotently creates the `analytics` user/DB |
| `bootstrap` | built locally | — (one-shot) | Initializes the `data` volume |

Compose project name: `analytics` (`COMPOSE_PROJECT_NAME`). Container names look
like `analytics-analytics-ui-1`, `analytics-northwind-db-1`, etc.

## Install (TUI)
After the binary is on PATH (`.deb` one-liner, source, or airgapped — see SKILL.md):
```
nqrust-analytics install
```
TUI screens, in order:
1. **Confirmation** — shows whether `.env` / `config.yaml` exist; offers Generate / Proceed / Cancel.
2. **Environment Setup** (if `.env` missing) — OpenAI API Key (required), Generation Model
   (default `gpt-4o-mini`), UI Port (3000), AI Service Port (5555). Save = **Ctrl+S**.
3. **Config Selection** (if `config.yaml` missing) — pick an AI provider template (OpenAI,
   Anthropic, Azure, DeepSeek, Gemini, Grok, Groq, Ollama, LM Studio, …). Enter to select.
4. **Installation Progress** — live docker compose logs + progress bar.
5. **Success/Error** — final result + full logs.

TUI key model (same as MicroVM): one key at a time, wait for the screen to settle,
re-read before the next key. Fields: `↑/↓` move, `Enter` edit, `Ctrl+S` save, `Esc` cancel.

## Required inputs the installer asks for (NEVER invent these)
- **OpenAI API key** (or the chosen provider's key) — required.
- **Generation model** — default `gpt-4o-mini`.
- **Ports** — UI 3000, AI service 5555 (change if busy).
- **GHCR PAT** with `read:packages` to pull images (`docker login ghcr.io`). See SKILL.md "Credentials".

## Post-install
- Open **http://<host>:3000**.
- **First registered user becomes admin.** Register with a real email + strong password.
- Optional OAuth (Google/GitHub) — edit `.env` (`GOOGLE_OAUTH_ENABLED=true` / `GITHUB_…`),
  add client id/secret, then `docker compose restart analytics-ui`.
- Optional SSO via NQRust Identity — `KEYCLOAK_OAUTH_ENABLED=true` + the `KEYCLOAK_*` vars
  in `.env` (this is the bridge to the Portal/Identity product).

## Key `.env` variables (from env_template)
- `OPENAI_API_KEY`, `GENERATION_MODEL`
- `ANALYTICS_UI_PORT=3000`, `ANALYTICS_ENGINE_PORT=8080`, `IBIS_SERVER_PORT=8000`,
  `ANALYTICS_AI_SERVICE_PORT`/`5555`
- `POSTGRES_PORT=5435`, `POSTGRES_USER=demo`, `POSTGRES_PASSWORD=demo123`, `POSTGRES_DB=northwind`
- `PG_URL=postgres://analytics:analytics123@northwind-db:5435/analytics` (the app DB; user
  `analytics`, created by `analytics-db-init`)
- `JWT_SECRET`, `NEXTAUTH_SECRET` — auth (installer auto-generates `JWT_SECRET`)
- `KEYCLOAK_OAUTH_ENABLED`, `KEYCLOAK_URL`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID/SECRET` — SSO bridge
- `LICENSE_KEY`, `LICENSE_SERVER_URL=https://billing.nexusquantum.id` — licensing

## Day-2 commands (run in the install dir)
- `docker compose ps` · `docker compose logs -f analytics-ui`
- Restart one service: `docker compose restart analytics-ui`
- Stop / start: `docker compose down` / `docker compose up -d`
- DB shell: `docker exec -it analytics-northwind-db-1 psql -U demo -d analytics`

## Install methods recap (decide at runtime — see SKILL.md)
- **.deb one-liner (preferred, online):**
  `curl -fsSL https://raw.githubusercontent.com/NexusQuantum/installer-NQRust-Analytics/main/scripts/install/install.sh | bash`
- **From source:** `git clone … && docker login ghcr.io && cargo run`
- **Airgapped:** build `nqrust-analytics-airgapped` on an online box (`./scripts/airgapped/build-single-binary.sh`,
  ~3–4 GB, bundles images), transfer, `chmod +x`, `./nqrust-analytics-airgapped install`.
