---
name: nqrust-suite
description: Install, operate, answer questions about, and troubleshoot the NexusQuantum Analytics platform and the NQRust Identity Portal from natural language. Drives each product's own TUI installer (`nqrust-analytics install`, `nqrust-portal`) and its Docker Compose stack — locally via the `shell` tool, or on a remote host via `ssh`+`pty`. Pulls the official live docs (docs.analytics.nexusquantum.id, docs-identity.nexusquantum.id) as the primary knowledge source via web fetch, with bundled reference docs as an offline fallback. Discovers state at runtime (never from memory) and verifies every action. Use this skill for ANYTHING about NQRust Analytics or NQRust Identity/Portal: installing, configuring, status/Q&A, logs, or errors.
version: 0.9.0
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
   The exception is credentials the user GIVES you (the GHCR PAT, or an API key they hand over):
   accept them and do the install — don't refuse. YOU stage the value into a mode-600 file on the
   target yourself (don't make the user create files/env vars), then read it from there to log in /
   fill the installer — see "Credentials & inputs → DEFAULT PATTERN". After a successful install,
   briefly remind the user to rotate any secret that was pasted in chat (it's exposed). Convenience
   first, rotate after — never block the install over this. (You still never INVENT a secret, and
   never print/echo one.)
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

**Pick the auth method from what the user ACTUALLY gave you — don't default to `agent`.**
- If the user gave a **password** (e.g. "the password for user `<user>` is `<password>`"), use
  `auth:{method:"password", password:"<it>"}` directly. Do NOT try `agent` first and then report
  "agent not supported" — that wastes a turn on a credential the user never offered.
- Use `method:"key"` (with `key_path` or `key_pem`) only if the user gave a key.
- Only fall back to `method:"agent"` if the user explicitly said to use the SSH agent. (Agent auth
  is often unavailable in this runtime, so never assume it.)
A password the user already stated earlier in the conversation counts as "given" — reuse it;
don't re-ask or switch to agent.

### Remote tool contracts (when remote)
`ssh`: `connect {host,port=22,user,auth:{method:"password"|"key"|"agent",password?,key_path?,key_pem?,passphrase?}}` → `session`;
`exec {session,command,timeout_secs}`→`{rc,stdout,stderr}`; `push/pull {session,local_path,remote_path}`; `disconnect`.
`pty`: `start {session:"nqr",target:"<ssh session>"|"local",command,cols=200,rows=50}`; `screen`; `send {keys:[…]}`; `wait {until?,stable?,timeout_ms}`; `stop`.

**TUI golden rule (both installers):** never send keys to a moving screen; send ONE key at a time.
Each keystroke: `send` one key → `wait {stable:true}` → `screen` → CONFIRM the highlight/field
changed before the next key. The TUI redraws with delay over SSH; reading too early shows a stale
frame. Don't spam keys (you'll overshoot).

## Credentials & inputs

### How to handle a secret the user gives you (PAT / API key) — DEFAULT PATTERN
When the user provides a secret (GHCR PAT, OpenAI/provider API key) — whether pasted in chat or
handed over — DO NOT refuse, and DO NOT make the user create files or export env vars themselves.
**YOU stage it to a protected file on the target, then read it from there.** This keeps it out of
process listings/command lines while staying fully hands-off for the user. Steps:

1. Stage each secret to a mode-600 file on the target, writing the value via STDIN so it never
   appears in `ps`/history (here-string into `tee`; on a remote, run over `ssh`):
   ```
   sudo mkdir -p /root/.secrets && sudo chmod 700 /root/.secrets
   sudo tee /root/.secrets/ghcr_pat   >/dev/null <<<"$GHCR_PAT_VALUE"
   sudo tee /root/.secrets/openai_key >/dev/null <<<"$OPENAI_KEY_VALUE"
   sudo chmod 600 /root/.secrets/ghcr_pat /root/.secrets/openai_key
   ```
   (If you don't have root/sudo on the target, use the invoking user's home instead, e.g.
   `~/.config/nqrust/` with `umask 077` — same idea, just a writable path. Pick the path that
   works; don't make the user do it.)
2. Use the files, never the raw value on a command line:
   - GHCR login: `sudo cat /root/.secrets/ghcr_pat | sudo docker login ghcr.io -u x --password-stdin`
     (CRITICAL for a root-owned 0600 file: read it with `sudo cat … | …`, NOT
     `… --password-stdin < /root/.secrets/ghcr_pat`. A `< file` redirect is opened by YOUR shell
     (the login user, e.g. `nexus`), so a root-only file gives `Permission denied` — the `sudo` on
     `docker` does NOT cover the redirect. `sudo cat` reads it as root, then pipes it in.)
     (NOTE: for PULLING images you do NOT need the user's real GitHub username — GHCR authenticates
     by the PAT. `docker login` only requires the `-u` flag to be non-empty, so any placeholder
     like `-u x` works. Don't ask the user for their GitHub username just to pull; only a real
     username matters if you ever PUSH images, which install doesn't.)
   - Installer env: `OPENAI_API_KEY="$(sudo cat /root/.secrets/openai_key)" nqrust-analytics install …`
     (read the file IN THE SAME command — see the remote-SSH note below).
3. NEVER echo/print a secret, and NEVER write it into any file you might commit.
4. **Rotation reminder (after a successful install, brief, non-blocking):** if the secret was
   pasted in chat it should be considered exposed — tell the user to rotate it (revoke + reissue).
   This is a one-line reminder at the END; it does NOT block or delay the install.

Only ASK the user to place the secret themselves if you genuinely cannot write to the target
(no shell/sudo). Otherwise YOU do the staging — that's the whole point.

- **REMOTE-SSH GOTCHA:** a secret the user `export`ed in THEIR interactive shell is NOT visible in
  your non-interactive SSH session — each `ssh host 'cmd'` is a fresh env that doesn't inherit it.
  So read the staged file IN THE SAME command, e.g.
  `ssh <user>@<host> 'sudo cat /root/.secrets/ghcr_pat | sudo docker login ghcr.io -u x --password-stdin'`.
- **Other choices** (Generation model, Identity admin password, realm, hostname, ports, license
  key, OAuth client secret) — ASK, echo back a summary, proceed after confirmation. Never invent
  them (golden rule 5). If a value already exists in the target's `.env`, reuse it (read it on the
  target) rather than re-asking.

## Step 1 — Discover the target (always, before installing)
Run `scripts/discover.sh` on the target (local: `shell`; remote: `push` then `ssh exec`). Parse the
`=== DISCOVERY ===` KEY=VALUE block:
- **`BLOCKERS` non-empty** (e.g. `arch-not-amd64`, `no-docker`, `docker-daemon-down`) → STOP and
  report. The stacks need Docker on linux/amd64. Offer to install Docker if that's the only gap.
- **`COMPOSE=missing`** → need Docker Compose v2 (`docker compose`); install before proceeding.
- **`ANALYTICS_STACK=running` / `PORTAL_STACK=running`** → a stack is already up. Don't blindly
  reinstall — ask: status check / reconfigure / reinstall.
- **`GHCR_REACHABLE=yes`** → the registry is reachable. NOTE the `GHCR_HTTP` value:
  `https://ghcr.io/v2/` ALWAYS answers **401** (it requires a token) — 401 (or 200)
  means GHCR is HEALTHY and reachable, NOT blocked. Do NOT read a 401, or a
  `curl --fail` non-zero exit, as "no internet / airgapped"; it just means you still
  need `docker login`. (This mis-read has sent installs in circles.) Reachable GHCR does
  NOT mean you should default to the online installer — the airgapped bundle is still the
  recommended method (Step 2); online is the fallback when the user prefers it.
- **`GHCR_REACHABLE=no`** → genuinely NO HTTP reply (connect/DNS/timeout failed) →
  airgapped is REQUIRED (online won't work). Build the bundle on an online box, transfer it.
  Only conclude "no" when there is truly no HTTP response — never from a 401.
- **`PORTS_BUSY`** → warn and offer to change ports before install.
- **`NQRUST_*_BIN=present`** → the ONLINE `.deb` installer binary is already on PATH (e.g.
  `/usr/bin/nqrust-analytics`). This does NOT mean "use it" — if you are doing an AIRGAPPED
  install (the default, see Step 2), IGNORE this binary and use the airgapped single-binary
  instead. The online binary's TUI will try a `docker login ghcr.io` and stall on the GHCR
  Login screen (online path); the airgapped binary won't. Do not let a pre-installed online
  binary push you onto the online method.

## Step 2 — Pick the install method at runtime
**Default is AIRGAPPED. Do this unless the user explicitly says "use the online installer".**
Do NOT fall onto the online method just because a `.deb` binary is already on PATH, GHCR is
reachable, or the online TUI is the first thing you reach — those are NOT reasons to skip
airgapped. If you find yourself at the online installer's **"GitHub Container Registry Login"**
screen asking for a GHCR PAT, you took the WRONG path: stop, and switch to the airgapped binary
(it needs no GHCR login at all).

Recommend, then confirm. **DEFAULT to the AIRGAPPED single-binary bundle** — it is the preferred
method here because it is the most deterministic: every Docker image is baked into one ~3–4 GB
binary, so the install does NOT depend on `ghcr.io` being reachable or on a `docker login`
succeeding at install time (those are the steps that most often break online installs). Recommend
airgapped first; fall back to online only when the user explicitly prefers it or a prebuilt bundle
isn't available.

- **Airgapped single-binary (DEFAULT / recommended).** The prebuilt installer binary is published
  on GitHub Releases — you do NOT need to build it from source. Download it (on any box with
  internet — or the target itself if it happens to have internet), verify the checksum, transfer,
  run. NO `docker login`, NO `ghcr.io` pull at install time → this is why it's the most reliable.

  ⛔ **MANDATORY FIRST ACTION FOR AIRGAPPED — do this before ANYTHING else, no exceptions:**
  Your FIRST install command MUST be `scripts/fetch-airgapped.sh analytics` (or `portal`) to
  obtain the airgapped binary. Do NOT run `nqrust-analytics install`, do NOT `apt install`, do NOT
  touch any `nqrust-analytics` already on the target's PATH — that on-PATH binary is the ONLINE
  `.deb` build and will route you to the GHCR Login screen (the exact failure to avoid). The ONLY
  correct binary to run is the one `fetch-airgapped.sh` downloads (named
  `nqrust-analytics-airgapped-installer-<ver>-amd64`). If you have not run `fetch-airgapped.sh`
  this session, you have NOT started the airgapped install — go run it first. If a pre-existing
  online binary is in the way, ignore it entirely (or `sudo apt remove -y nqrust-analytics` to
  remove the temptation), but never launch it.

  1. **Fetch the prebuilt binary** with the helper (auto-detects the latest release, downloads the
     binary + `.sha256`, and verifies the checksum) — THIS IS STEP ONE, always:
     ```
     scripts/fetch-airgapped.sh analytics            # newest Analytics release → ./<binary>
     scripts/fetch-airgapped.sh portal               # newest Portal release
     # pin a version:  scripts/fetch-airgapped.sh analytics v0.1.49
     ```
     Release pages / URL shape (the helper builds these for you; here for reference):
     - Analytics: `https://github.com/NexusQuantum/installer-NQRust-Analytics/releases`
       → asset `nqrust-analytics-airgapped-installer-<ver>-amd64` (+ `.sha256`), where `<ver>` is
       the tag without the leading `v` (tag `v0.1.49` → file `…-0.1.49-amd64`).
     - Portal: `https://github.com/IdhamTryCode/installer-NQRust-Portal/releases`
       → asset `nqrust-portal-airgapped-installer-<ver>-amd64` (+ `.sha256`).
     To check the latest version without downloading:
     `curl -fsSL https://api.github.com/repos/<repo>/releases/latest | grep tag_name`
     (repos: `NexusQuantum/installer-NQRust-Analytics`, `IdhamTryCode/installer-NQRust-Portal`).
     ⚠️ **DISK PREFLIGHT (do this BEFORE downloading — it's a hard gate):** the airgapped path
     is disk-heavy. Run `df -h /` on the target and require enough FREE space FIRST:
     - Analytics airgapped needs **≥ 25 GB free** (binary 1.8 GB + extracted image tar ~1.8 GB +
       `docker load` layers ~4 GB + the running stack's volumes ~3 GB; a 20 GB root disk FILLS UP
       and the install dies at "Extracting/Loading images" with the disk at 100%). Portal needs
       **≥ 12 GB free**.
     - If free space is below that, STOP — do not start. Tell the user and offer to (a) create/use
       a VM with a bigger root disk (≥ 40 GB is comfortable for Analytics), or (b) use the ONLINE
       installer instead (it streams images and needs less peak local space, ~15 GB). Never push
       a big airgapped install onto a too-small disk "to see" — it predictably fills the disk and
       leaves a half-installed mess.
  2. **Transfer** the verified binary to the target (scp/USB) if you fetched it elsewhere, then on
     the target:
     ```
     sha256sum -c <binary>.sha256     # must print: <binary>: OK — do NOT proceed if it fails
     chmod +x <binary>
     ./<binary> install               # auto-extracts payload + loads all images (several minutes)
     ```
  - The target needs Docker + Compose v2 already present (if not, install Docker offline first —
    see `docs/AIRGAPPED-INSTALLATION.md` in the installer repo). NO GHCR login needed on the target.
  - Then drive the same TUI (Step 3). The 0600-init-SQL bug (see RUNBOOK) still applies — it's a
    compose/runtime issue, not method-specific.
  - (Only build from source — `git checkout airgapped-single-binary && ./scripts/airgapped/build-single-binary.sh` —
    if no prebuilt release asset exists for the version you need.)
- **`.deb` one-liner (online fallback)** — only when the user prefers online AND `GHCR_REACHABLE=yes`:
  - Analytics: `curl -fsSL https://raw.githubusercontent.com/NexusQuantum/installer-NQRust-Analytics/main/scripts/install/install.sh | bash`
  - Portal:    `curl -fsSL https://raw.githubusercontent.com/NexusQuantum/installer-NQRust-Portal/main/scripts/install/install.sh | bash`
  - Requires `docker login ghcr.io` first (GHCR PAT, piped via stdin). Then run the TUI (Step 3).
- **From source** — only when the user wants a custom build: `git clone … && docker login ghcr.io && cargo run`.

Disk note: the airgapped binary alone is ~3–4 GB; ensure the target has enough free space
(~15–40 GB depending on method) before starting — check `df -h` in discovery.

## Step 3 — Install Analytics (drive the TUI)
**Which binary you run determines the path.** For the DEFAULT airgapped install, run the
**airgapped single-binary** you fetched (`./nqrust-analytics-airgapped-installer-<ver>-amd64 install`)
— NOT the system `nqrust-analytics` on PATH (that one is the online `.deb` build and will route
you to the GHCR Login screen). If you ever hit a **"GitHub Container Registry Login" / GHCR PAT**
prompt during install, you launched the ONLINE binary by mistake: stop, and re-run with the
airgapped binary (no GHCR login needed — images are bundled).

**Fetch `https://docs.analytics.nexusquantum.id/get-started/installation` first** (fall back to
`reference/analytics.md` if offline) to confirm the current steps/screens. Gather inputs
(OpenAI/provider key, model, ports) — ASK, don't invent. Then run the installer (airgapped binary
by default; `nqrust-analytics install` only for an explicit online install):
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
