# Tutorial — Install & operate the NQRust Suite (Analytics + Identity Portal) with the agent

A goal-oriented walkthrough. By the end you'll have used a RantaiClaw agent to **install**
NexusQuantum Analytics and the NQRust Identity Portal, **ask** about their state, and
**troubleshoot** errors — all from natural language. The agent drives each product's own TUI
installer and its Docker Compose stack; it never invents status and verifies every change.

## 0. Mental model

- You run **RantaiClaw** (the agent) on your machine. The `nqrust-suite` skill is the playbook.
- The agent works **locally** (the `shell` tool) when the stack lives on this machine, or
  **remotely** (`ssh` + `pty`) when you point it at another host over SSH. You choose; if you
  don't say, it asks.
- It does NOT re-implement installs — it **drives `nqrust-analytics install` / `nqrust-portal`**
  (the products' own TUIs) and `docker compose`, then adds discovery, install-method choice,
  verification, Q&A, and troubleshooting.
- It **discovers at runtime** (Docker? Compose v2? GHCR reachable? ports busy?) and **verifies**
  every install/change with a real `docker ps` + health probe before claiming success.
- It **asks** for every secret/choice (OpenAI key, admin password, license key, hostname, ports,
  OAuth client secret) — it never makes them up.
- For how-to/conceptual questions it reads the **official live docs** first and cites them —
  [docs.analytics.nexusquantum.id](https://docs.analytics.nexusquantum.id) and
  [docs-identity.nexusquantum.id](https://docs-identity.nexusquantum.id) — falling back to the
  skill's bundled `reference/` docs when offline.

## 1. Prerequisites

- **Docker + Docker Compose v2** on the target (linux/amd64). The agent checks and will tell you
  if either is missing.
- A **GitHub PAT** with `read:packages` to pull images from `ghcr.io`. Configure it **once** so
  the agent can use it without it ever showing in chat:
  ```bash
  export GHCR_PAT=ghp_xxxxxxxxxxxxxxxxxxxx        # or run: docker login ghcr.io
  ```
  > Treat this PAT as a secret. Don't paste it into chat or commit it anywhere — if it leaks,
  > revoke it at https://github.com/settings/tokens and issue a new one.
- RantaiClaw with an LLM provider (`rantaiclaw onboard`) and the skills deployed (`./install.sh`,
  which now includes `nqrust-suite`).

## 2. Install Analytics

```bash
rantaiclaw chat        # or use the web console (./web-ui.sh)
```
Ask in plain language. Locally:
```
install NexusQuantum Analytics on this machine. My OpenAI key is in $OPENAI_API_KEY,
model gpt-4o-mini, UI on port 3000. Discover first, drive the installer, verify, report.
```
Or on a remote host:
```
install NexusQuantum Analytics on 10.0.0.5, ssh user ubuntu, key ~/.ssh/id_ed25519.
```
The agent will: run discovery → recommend an install method (`.deb` one-liner by default; airgapped
if no internet) → ask for anything missing → drive the TUI (Confirmation → Environment → Config
provider → Progress) → then **verify** with `docker ps` + a health probe and report
**http://&lt;host&gt;:3000**.

> **First registered user becomes the admin.** Open the UI, register with a real email + strong
> password.

## 3. Install the Identity Portal (two phases)

The Portal install has **two phases** with a human step in the Identity admin console between them.
The agent walks you through it.

**Phase 1:**
```
install the NQRust Identity Portal on this machine. Hostname portal.example.com,
portal port 8083, identity port 8082. I'll give the admin password when asked.
```
The agent brings up the stack (Traefik + Identity + Identity DB + Portal), verifies the containers
and Identity health, and reports Portal `https://<host>:8083` and Identity admin
`https://<host>:8082/admin`.

**Between phases (you do this in the browser):** open the Identity admin console, log in with the
Phase-1 admin password, create/configure the `nqrust-portal` client, set the **Valid redirect URIs**
and Root/Home/Web-origin/Admin URLs to `https://<host>:8083`, and copy the **client secret**.

**Phase 2:**
```
here's the Portal client secret: <paste>. Apply Phase 2.
```
The agent re-runs the installer in Phase 2 mode to apply the secret + realm, then verifies again.

**Finish:** activate the license at `https://<host>:8083/license-activation`, then log in via OIDC →
`https://<host>:8083/dashboard`.

> The browser will warn about a **self-signed certificate** — that's expected for the Portal
> (Traefik). Click Advanced → Proceed.

## 4. Ask questions (Q&A)

The agent answers only from live state — it runs a command and reads the output:
```
is analytics up?   ·   which portal containers are running, and are they healthy?
what port is the analytics UI on?   ·   how many containers are restarting?
show me the last 200 lines of the analytics-ui log
```

## 5. Troubleshoot

Describe the symptom; the agent observes first, then fixes (and re-verifies):
```
analytics login fails: 'password authentication failed for user "analytics"'
portal login loops back to the sign-in page after I authenticate
images won't pull — 'unauthorized' from ghcr.io
```
It matches the symptom against `skill/nqrust-suite/RUNBOOK.md`, applies the fix (confirming first
if anything is destructive, e.g. dropping a Postgres volume), and re-checks the real state.

## 6. (Optional) Wire Analytics SSO to the Portal/Identity

Once both are up, the Portal's Identity provider can be the SSO source for Analytics:
```
enable SSO on Analytics using the NQRust Identity at https://portal.example.com:8082, realm master
```
The agent sets `KEYCLOAK_OAUTH_ENABLED=true` and the `KEYCLOAK_*` vars in the Analytics `.env`
(using an Identity client created for Analytics), then restarts `analytics-ui`.

## What the agent will and won't do

- **Will:** discover, recommend, ask for what it needs, drive the installers, verify with real
  output, quote real logs/errors, and confirm before destructive changes.
- **Won't:** invent a status, a port, a password, or a "success" it didn't verify; print your GHCR
  PAT or other secrets; reinstall over a running stack without asking.
