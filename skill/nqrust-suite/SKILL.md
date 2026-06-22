---
name: nqrust-suite
description: Install, operate, answer questions about, and troubleshoot the NexusQuantum Analytics platform and the NQRust Identity Portal from natural language. Drives each product's own TUI installer (`nqrust-analytics install`, `nqrust-portal`) and its Docker Compose stack — locally via the `shell` tool, or on a remote host via `ssh`+`pty`. Pulls the official live docs (docs.analytics.nexusquantum.id, docs-identity.nexusquantum.id) as the primary knowledge source via web fetch, with bundled reference docs as an offline fallback. Discovers state at runtime (never from memory) and verifies every action. Use this skill for ANYTHING about NQRust Analytics or NQRust Identity/Portal: installing, configuring, status/Q&A, logs, or errors.
version: 0.1.0
tags: [installer, analytics, identity, portal, docker, compose, ssh, tui, operations, troubleshooting]
---

# NQRust Suite — Analytics + Identity/Portal (install · Q&A · troubleshoot)

This skill handles the two NQRust product stacks:

- **NexusQuantum Analytics** — NL analytics platform. TUI installer `nqrust-analytics install`
  → Docker Compose stack (UI :3000, engine, ibis, AI/RAG service, Qdrant, Postgres).
  Details: `reference/analytics.md`.
- **NQRust Identity Portal** — OIDC Identity provider + Portal behind Traefik HTTPS, license-gated.
  TUI installer `nqrust-portal` → Docker Compose stack. **Two-phase install.**
  Details: `reference/portal.md`.

You do NOT re-implement any install or runtime logic. You **drive each product's own TUI
installer and its `docker compose` stack**, and you add: discovery, install-method selection,
requirement gathering, verification, Q&A, and troubleshooting. Troubleshooting playbook:
`RUNBOOK.md`. Before driving an install or answering a how-to question, **fetch the official live
docs first** (see "Documentation sources" below) — they're the primary source of truth; the local
`reference/*.md` (exact screens, ports, services, env vars) is the offline fallback.

## GOLDEN RULES (read first, every time)
1. NEVER answer a status/health/config question from memory or a "plausible" guess. ALWAYS run
   the relevant command THIS turn (`scripts/status.sh`, `docker ps`, `docker compose ps`,
   `docker compose logs`, a health `curl`) and base the answer ONLY on its real stdout.
2. NEVER invent container names, ports, URLs, counts, statuses, or log lines. If you did not see
   it in command output this turn, you do not know it.
3. NEVER claim an install/start/stop/restart/config-change succeeded unless you ran a VERIFY
   command THIS turn and saw the expected state. Running a command is not success — `docker
   compose up` can pull-fail, a container can crash-loop, a port can conflict. "Installed" /
   "done" without a confirming `docker ps` + health probe is a CRITICAL failure.
4. If a command errors or exits non-zero: QUOTE the exact error, state plainly that it FAILED,
   give the likely cause (check `RUNBOOK.md`), and stop — do not substitute a guessed result.
5. NEVER invent or auto-generate user-facing secrets/choices (OpenAI key, admin password, license
   key, hostname, ports, OAuth client secret). ASK and confirm — see "Credentials & inputs".
   The ONLY exception is the GHCR pull PAT, which you source from the environment/workspace
   (see below) and never print.
6. Give ONE final answer. Don't state a number/list then retract it in the same reply.
7. Answer in the user's language (Indonesian if they write Indonesian).
8. Count literally: data rows in the output = the count. Report the list AND the count.
9. NAMING — call them **NexusQuantum Analytics** (or "Analytics") and **NQRust Identity Portal**
   (or "Portal"/"Identity") in everything you write. Keep real identifiers exact inside commands
   (container names like `nqrust-identity`, env keys like `KEYCLOAK_*`) — don't rewrite them.

## Tools
- name: shell    # local: run docker / installer / status on this machine
  kind: builtin
- name: ssh      # remote: transport to a target host
  kind: builtin
- name: pty      # remote: drive the TUI installer over tmux
  kind: builtin

Also use RantaiClaw's **web fetch** capability to read the official docs sites (the primary
knowledge source — see below).

## Documentation sources (live docs are PRIMARY — fetch them first)
The official, always-current docs are the **primary** source of truth for how-to and conceptual
questions and for install steps. **Fetch** the relevant page (use RantaiClaw's web fetch) BEFORE
answering a how-to/conceptual question and BEFORE driving an install, then **cite the URL** you
used. Use the
local `reference/analytics.md` / `reference/portal.md` as a **fallback** only when the fetch fails,
the host is **airgapped** (`GHCR_REACHABLE=no` from discovery), or you just need the exact
compose/env facts they pin down.

- **Analytics** — base `https://docs.analytics.nexusquantum.id`
  - `/get-started/installation` · `/get-started/quickstart` · `/get-started/connect-your-data`
    · `/get-started/sample-data` · `/accounts/overview` · `/accounts/oauth` (SSO)
- **Identity / Portal** — base `https://docs-identity.nexusquantum.id` (paths are
  **locale-prefixed**, use `/en/…`; an `/id/…` Indonesian version also exists)
  - `/en/getting-started` · `/en/guides/installation` · `/en/guides/installation/phase-1-identity`
    · `/en/guides/installation/phase-2-portal` · `/en/guides/installation/add-new-client`
  - deeper sections exist under `/en/guides/server/…`, `/en/guides/observability/…`,
    `/en/guides/securing-applications/…`, `/en/guides/high-availability/…`.

Neither site publishes a `sitemap.xml`. If you need a page you don't have a path for, fetch the
base URL (or the nearest section index) and read its nav links to discover the right path, then
fetch that. NEVER fabricate a docs URL or quote docs content you didn't fetch this turn — if a
fetch 404s or fails, say so and fall back to `reference/*.md` (golden rules 1–2 still apply).
Live state (`docker ps`/health) ALWAYS overrides docs for "what is true right now" questions —
docs tell you how it *should* work; the target tells you how it *is*.

## Local vs remote — decide FIRST (both are supported)
Figure out WHERE Analytics/Portal should run before doing anything:

- **Local** — claw runs on the same host the stack should live on. Use the **`shell`** tool for
  everything: discovery, the installer TUI (it's interactive — run it and drive it), `docker`,
  status. This is the simpler path (like the Hypervisor skill).
- **Remote** — the user names a host/IP + SSH credential (or says "on 10.x.x.x"). Use **`ssh`**
  to connect and run commands, and **`pty`** to drive the installer TUI over tmux (exactly like
  the MicroVM skill). `push` the helper scripts to the target, run them with `ssh exec`.

If the user didn't say, ASK: "Install locally on this machine, or on a remote host over SSH?"
Don't assume. For remote, you also need host, user, and one SSH credential (password / key /
agent) — ask for whatever's missing. Never echo a password or key.

### Remote tool contracts (when remote)
`ssh`: `connect {host,port=22,user,auth:{method:"password"|"key"|"agent",password?,key_path?,key_pem?,passphrase?}}` → `session`;
`exec {session,command,timeout_secs}`→`{rc,stdout,stderr}`; `push/pull {session,local_path,remote_path}`; `disconnect`.
`pty`: `start {session:"nqr",target:"<ssh session>"|"local",command,cols=200,rows=50}`; `screen`; `send {keys:[…]}`; `wait {until?,stable?,timeout_ms}`; `stop`.

**TUI golden rule (both installers):** never send keys to a moving screen; send ONE key at a time.
Each keystroke: `send` one key → `wait {stable:true}` → `screen` → CONFIRM the highlight/field
changed before the next key. The TUI redraws with delay over SSH; reading too early shows a stale
frame. Don't spam keys (you'll overshoot).

## Credentials & inputs
- **GHCR pull PAT** (`read:packages`) — needed to pull images from `ghcr.io`. SOURCE it, never ask
  for it interactively in chat and NEVER print it:
  1. Prefer env var **`$GHCR_PAT`** (or `$GHCR_TOKEN`).
  2. Else a workspace token file (e.g. `<workspace>/ghcr-token`, mode 600) if present.
  3. Use it only via `docker login ghcr.io -u <user> --password-stdin` (pipe it; don't put it on
     the command line, don't echo it, don't write it into any file you might commit).
  If none is configured, tell the user to set `GHCR_PAT` (or run `docker login ghcr.io`) — do not
  hardcode a token anywhere.
- **All other secrets/choices** (OpenAI/provider API key, Generation model, Identity admin
  password, realm, hostname, ports, license key, OAuth client secret) — ASK the user, echo back a
  summary, proceed only after confirmation. Never invent them (golden rule 5). If a value already
  exists in the target's `.env`, you may reuse it (read it on the target) rather than re-asking.

## Step 1 — Discover the target (always, before installing)
Run `scripts/discover.sh` on the target (local: `shell`; remote: `push` then `ssh exec`). Parse the
`=== DISCOVERY ===` KEY=VALUE block:
- **`BLOCKERS` non-empty** (e.g. `arch-not-amd64`, `no-docker`, `docker-daemon-down`) → STOP and
  report. The stacks need Docker on linux/amd64. Offer to install Docker if that's the only gap.
- **`COMPOSE=missing`** → need Docker Compose v2 (`docker compose`); install before proceeding.
- **`ANALYTICS_STACK=running` / `PORTAL_STACK=running`** → a stack is already up. Don't blindly
  reinstall — ask: status check / reconfigure / reinstall.
- **`GHCR_REACHABLE=no`** → likely airgapped → recommend the **airgapped** install method.
- **`PORTS_BUSY`** → warn and offer to change ports before install.
- **`NQRUST_*_BIN=present`** → the installer binary is already on PATH; skip re-download.

## Step 2 — Pick the install method at runtime
Recommend, then confirm. Decide from discovery + user intent:
- **`.deb` one-liner (default, preferred)** when `GHCR_REACHABLE=yes` and no binary yet:
  - Analytics: `curl -fsSL https://raw.githubusercontent.com/NexusQuantum/installer-NQRust-Analytics/main/scripts/install/install.sh | bash`
  - Portal:    `curl -fsSL https://raw.githubusercontent.com/NexusQuantum/installer-NQRust-Portal/main/scripts/install/install.sh | bash`
  - Then run the TUI (Step 3).
- **From source** when the user wants it / a custom build: `git clone … && docker login ghcr.io && cargo run`.
- **Airgapped** when `GHCR_REACHABLE=no` or the user says offline: on an online box build the
  single binary (`./scripts/airgapped/build-single-binary.sh`, ~3–4 GB, bundles images), transfer +
  verify checksum, `chmod +x`, run it. (Docker itself may also need an offline install — see each repo's airgapped docs.)
Ensure `docker login ghcr.io` is done first for `.deb`/source (use the GHCR PAT, piped via stdin).

## Step 3 — Install Analytics (drive the TUI)
**Fetch `https://docs.analytics.nexusquantum.id/get-started/installation` first** (fall back to
`reference/analytics.md` if offline) to confirm the current steps/screens. Gather inputs
(OpenAI/provider key, model, ports) — ASK, don't invent. Then run `nqrust-analytics install`:
- **Local:** run it with `shell`; it's an interactive TUI — drive it (fields `↑/↓`, `Enter` edit,
  `Ctrl+S` save, `Esc` cancel). Screens in order: Confirmation → Environment Setup (if `.env`
  missing) → Config Selection (provider template) → Progress → Success/Error.
- **Remote:** `pty start {command:"nqrust-analytics install"}` and walk the screens one key at a
  time (TUI golden rule). If `[sudo] password` appears, send it scrubbed.
**VERIFY (mandatory):** `scripts/status.sh analytics` → all containers Up, `ANALYTICS_UI` health
returns a real HTTP code. Then report the URL **http://<host>:3000** and that the **first
registered user becomes admin**. Only claim success after this check.

## Step 4 — Install Portal/Identity (TWO PHASES — drive the TUI)
**Fetch the live docs first:** `https://docs-identity.nexusquantum.id/en/guides/installation/phase-1-identity`
and `…/phase-2-portal` and `…/add-new-client` (fall back to `reference/portal.md` if offline).
This is the part that trips people up: it's two phases with a human admin-console step in between.
- **Gather Phase-1 inputs:** hostname/IP, Portal Port (8083), Identity Port (8082), **admin
  password** (ASK), realm (master), client id (nqrust-portal). Leave client secret blank.
- **Run Phase 1:** `nqrust-portal` (local: drive TUI via shell; remote: via pty). VERIFY: `status.sh
  portal` → `nqrust-traefik`, `nqrust-identity`, `nqrust-identity-db`, `nqrust-identity-portal` Up;
  Identity health (`docker exec nqrust-identity curl -fsS http://localhost:9000/health/ready`).
  Report Portal `https://<host>:8083` and Identity admin `https://<host>:8082/admin`.
- **PAUSE for the human step:** tell the user to (1) open the Identity admin console, log in with
  the Phase-1 admin password, (2) create/configure the `nqrust-portal` client, (3) set Valid
  redirect URIs + Root/Home/Web-origin/Admin URLs to `https://<host>:8083`, (4) copy the client
  secret. You CANNOT invent the client secret — wait for it.
- **Run Phase 2:** re-run `nqrust-portal`, select **Phase 2**, apply the client secret + realm.
  VERIFY again with `status.sh portal`, and confirm `KEYCLOAK_CLIENT_SECRET` is set in `.env`.
- Tell the user: activate the **license** at `https://<host>:8083/license-activation`, then login
  via OIDC → `https://<host>:8083/dashboard`. Note the expected **self-signed cert warning**.

(Optional "full suite" wiring: Portal/Identity is the SSO source for Analytics — to enable, set
`KEYCLOAK_OAUTH_ENABLED=true` + the `KEYCLOAK_*` vars in the Analytics `.env`, using an Identity
client created for Analytics. See the bottom of `reference/portal.md`.)

## Q&A — answering questions about a running stack
There are TWO kinds of questions — route them differently:
- **"How does X work / how do I configure Y / what does Z mean"** (conceptual / how-to) →
  **fetch the relevant docs page** (see "Documentation sources"), answer from it, and **cite the
  URL**. Fall back to `reference/*.md` only if the fetch fails or the host is airgapped.
- **"What is TRUE right now"** (status/health/config of THIS deployment) → run a command and answer
  from output. Live state always wins over docs here. Run, then answer from output:
- "is analytics up / which services are running / what's the URL?" → `scripts/status.sh analytics`
  (or `all`), then answer from the table + health codes.
- "is the portal healthy / is identity ready?" → `scripts/status.sh portal` + the Identity
  health exec.
- "what port / what's in the config?" → read the real `.env` / `docker compose config` on the
  target; quote actual values. Don't recite defaults as if confirmed — verify.
- "how many containers / what's restarting?" → `docker ps` / `docker compose ps`; count rows.
Lead with the direct answer, then a short table (real Name/Status/Port only). Offer a next step.

## Troubleshooting
1. Reproduce/observe FIRST: `scripts/status.sh all`, then `scripts/logs.sh <failing-container> 200`,
   and `docker compose ps`. Quote the real error text.
2. Match it in **`RUNBOOK.md`** (GHCR unauthorized, port conflict, the `role "analytics" does not
   exist` Postgres-init gotcha, Document RAG callback, Qdrant 409, Portal OAuth redirect mismatch,
   Identity not healthy, Traefik 404, self-signed cert warning, …). For anything the RUNBOOK
   doesn't cover, **fetch the relevant docs page** (e.g. the Identity `server`/`securing-applications`
   sections) and cite it.
3. State the cause and the fix in plain language. For any mutating fix (recreate volume, restart,
   change `.env`) CONFIRM with the user first if it's destructive (e.g. dropping a Postgres volume
   = data loss). Apply, then **re-verify** with `status.sh`/`logs.sh` and report the real new state.
4. If you can't determine the cause, say so and present the gathered evidence — don't fabricate a
   root cause or claim a fix worked without re-checking.

## Output & communication style
- Lead with the direct answer (status / URL / count), then a compact table.
- When you ran a command, it's fine to say which; never claim a command/output you didn't run/get.
- For installs, end with: access URL(s), the one credential reminder (Analytics: first user =
  admin; Portal: activate license + self-signed cert warning), and a sensible next step.
