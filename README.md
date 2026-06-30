# NQRust-Infra-AI

An AI agent that **installs and operates NQRust infrastructure from natural language** — powered
by [RantaiClaw](https://github.com/RantAI-dev/RantAIClaw). It ships RantaiClaw **skills**, one
product family at a time, plus the **NQRust web console** — a browser UI that's the easiest way to
drive the agent.

This repo ships **only the skills** (playbooks + helper scripts) and the web-console brand; the
underlying capabilities live in RantaiClaw itself — the `ssh`/`pty` tools (the `remote-install`
feature) and the `shell` tool.

You drive it in **plain language** — easiest in the **[web console](#web-console-recommended)** (a
browser UI; what most people use), or from a terminal if you prefer. Just ask:

```
Install nqrust-microvm on 10.0.0.5, ssh user ubuntu, key ~/.ssh/id_ed25519. Minimal, NAT.
list all VMs on the Hypervisor cluster   ·   which nodes are unhealthy?
```

## Products

| Product | What the agent does | Tutorial |
|---|---|---|
| **[NQRust-MicroVM](https://github.com/NexusQuantum/NQRust-MicroVM)** — Firecracker microVMs | **install** (drives the `nqr-installer` TUI over SSH/tmux) + **operate** (`nqvm` CLI) | [tutorials/microvm.md](tutorials/microvm.md) |
| **Hypervisor** — KubeVirt + Longhorn (HCI) | **operate** an existing cluster via `kubectl` (list/create/start/stop VMs, images, storage, networks, backups) | [tutorials/hypervisor.md](tutorials/hypervisor.md) |
| **NQRust Suite** — [Analytics](https://github.com/NexusQuantum/installer-NQRust-Analytics) + [Identity Portal](https://github.com/NexusQuantum/installer-NQRust-Portal) | **install** (drives each product's TUI installer + Docker Compose, locally or over SSH), **answer questions**, and **troubleshoot** both stacks | [tutorials/suite.md](tutorials/suite.md) |

More products will land over time — each adds a skill under `skill/` and a tutorial under
`tutorials/`; installation and the web console below stay the same.

## How it works

- You run **RantaiClaw** (the agent) on your machine. It's a general-purpose agent — this repo
  just teaches it NQRust products via **skills** (Markdown playbooks the model follows).
- The agent uses RantaiClaw's built-in **tools** to do the real work:
  - **`ssh` + `pty`** — SSH in and drive a product's installer TUI / CLI on a remote host (MicroVM).
  - **`shell`** — run `kubectl` locally against a cluster (Hypervisor).
- The skills don't re-implement anything; they **drive each product's own installer/CLI** and add
  discovery, recommendations, verification, and reporting.

## Prerequisites

1. **RantaiClaw with the remote-install tools** — the prebuilt bundle (below) ships it; from
   source, see *Getting a RantaiClaw with the tools*.
2. **An LLM provider** configured in RantaiClaw (`rantaiclaw onboard`) — the agent is model-driven.
3. **For MicroVM — a target host:** Ubuntu/Debian **x86_64 with KVM** (`/dev/kvm`), reachable over
   SSH, with sudo. You do **not** need `ssh`/`tmux` on your own machine — RantaiClaw connects
   in-process and installs `tmux` on the target during preflight.
4. **For the Hypervisor — `kubectl` on your machine + a kubeconfig.** The skill drives the cluster
   **locally** over `kubectl` (not over SSH). Drop the kubeconfig in the RantaiClaw workspace as
   `kubeconfig-hypervisor` (the skill can install/rotate it for you).

## Install the agent

**Fastest — prebuilt bundle (recommended).** Ships a static `rantaiclaw` (with the ssh+pty tools)
+ all the skills + the `nqvm` CLI. You only add your LLM key. Linux x86_64:

```bash
curl -fsSL https://raw.githubusercontent.com/NexusQuantum/NQRust-Infra-AI/master/get.sh | bash
rantaiclaw onboard      # set your LLM provider + key
rantaiclaw chat
```

**From source** (other platforms, or you already run your own RantaiClaw):

```bash
git clone https://github.com/NexusQuantum/NQRust-Infra-AI
cd NQRust-Infra-AI
./install.sh            # deploy the skills, verify the tools, stage nqvm, brand the web console
```

**Web console (recommended)** — the easiest way to drive the agent: a browser UI (chat + watch it
work). It's a separate Next.js app (not in the bundle), so use the git clone:
```bash
./web-ui.sh             # → http://localhost:3939   (see Web console below)
```

> **Getting a RantaiClaw with the tools** — the `ssh`/`pty` tools are general RantaiClaw
> capabilities behind the `remote-install` feature (in `default`). Until upstreamed, build from
> the feature branch:
> ```bash
> git clone https://github.com/RantAI-dev/RantAIClaw
> cd RantAIClaw && git checkout feature/ssh-pty-tools
> cargo build --release --features remote-install
> install -m755 target/release/rantaiclaw ~/.local/bin/rantaiclaw
> ```

## NQRust-MicroVM

Install and operate Firecracker microVMs on a remote host. **Full walkthrough →
[tutorials/microvm.md](tutorials/microvm.md).**

**Install** — give the agent host + user + one SSH credential (+ sudo). It discovers the host,
recommends a config, drives the real `nqr-installer` TUI over tmux, verifies, and reports. In the
**web console** (or `rantaiclaw chat`), just ask:

```
Install nqrust-microvm on 10.0.0.5, ssh user ubuntu, key ~/.ssh/id_ed25519.
Minimal mode, NAT. Discover first, drive the installer to completion, verify, report.
```

`ssh`/`pty` are **always-ask** — approve each step with **Y**; reply **`continue`** when it pauses.
Watch live with `tmux attach -t nqr` on the target. Done → **Manager API** `http://<host>:18080`,
**MicroVM Web UI** `http://<host>:3000` (Production; default login `root`/`root` — change it).

| SSH credential | Example phrasing |
|---|---|
| Password (SSH + sudo) | `ssh user ubuntu password 's3cret'` |
| Key + passwordless sudo | `ssh user ubuntu, key ~/.ssh/id_ed25519` |
| Key + separate sudo password | `ssh user ubuntu, key ~/.ssh/id_ed25519, sudo password 's3cret'` |
| ssh-agent (nothing secret typed) | `ssh user ubuntu, use my ssh agent` |

**Operate** (after install) — plain language; drives NQRust-MicroVM's own `nqvm` CLI over SSH:

```
on 10.0.0.5 create a microVM named web, 2 vCPU 1GB from the ubuntu-24.04 image, start it
list my VMs   ·   stop web   ·   snapshot web   ·   deploy nginx as a container   ·   delete web
```

## Hypervisor

Operate an existing **Hypervisor** cluster (KubeVirt VMs + Longhorn storage) over `kubectl` — no
SSH, no install. **Full walkthrough → [tutorials/hypervisor.md](tutorials/hypervisor.md).**

Put a kubeconfig in the workspace (or let the agent install/rotate it):
```bash
cp ~/Downloads/kubeconfig.yaml ~/.rantaiclaw/profiles/default/workspace/kubeconfig-hypervisor
```
Then, in the **web console** (or `rantaiclaw chat`), just ask:
```
list all VMs on the Hypervisor cluster   ·   which nodes are unhealthy?   ·   list VM images
create a VM named web, 2 vCPU 2GB, ubuntu cloud image, on the lab network, with my SSH key
stop web   ·   show storage volumes
```

The `nqrust-hypervisor` skill discovers the cluster at runtime (never from memory), gathers
requirements before creating anything (it won't invent credentials or pick a network), and
verifies every mutation with a follow-up `kubectl get`. Needs `kubectl` locally (see Prerequisites).

## NQRust Suite — Analytics + Identity Portal

Install, ask about, and troubleshoot **NexusQuantum Analytics** and the **NQRust Identity
Portal** — locally on this machine or on a remote host over SSH. **Full walkthrough →
[tutorials/suite.md](tutorials/suite.md).**

The `nqrust-suite` skill drives each product's own TUI installer (`nqrust-analytics install`,
`nqrust-portal`) and its Docker Compose stack. It discovers the target first (Docker? Compose v2?
GHCR reachable? ports busy?), picks an install method at runtime (`.deb` one-liner / from source /
airgapped), gathers the inputs it needs (it **asks** for the OpenAI key, admin password, license
key, hostname, ports — it never invents them), and **verifies** every install/change with a real
`docker ps` + health probe before reporting success. For how-to and conceptual questions it pulls
the **official live docs** as the primary source — [docs.analytics.nexusquantum.id](https://docs.analytics.nexusquantum.id)
and [docs-identity.nexusquantum.id](https://docs-identity.nexusquantum.id) — and cites them, with
the bundled `reference/` docs as an offline fallback.

Prereqs: **Docker + Docker Compose v2** on the target (linux/amd64), and a **GHCR PAT** with
`read:packages` to pull images. Configure the PAT once via the `GHCR_PAT` env var (or
`docker login ghcr.io`) — the skill sources it from there and never prints it. In the **web
console** (or `rantaiclaw chat`), just ask:

```
install NexusQuantum Analytics locally; OpenAI key in $OPENAI_API_KEY, UI on port 3000
install the NQRust Identity Portal on 10.0.0.7 over SSH, hostname portal.example.com
is analytics up?   ·   which portal containers are running?   ·   show analytics-ui logs
analytics login fails with 'role analytics does not exist' — fix it
```

The Portal install is **two-phase** (Phase 1 brings up the stack; Phase 2 applies the OAuth client
config after you create the client in the Identity admin console) — the skill pauses between them
and tells you exactly what to do in the admin UI. Self-signed TLS on the Portal is expected.

## Web console (recommended)

**The easiest way to use the agent** — chat with it and watch it work, in your browser. This
**NQRust-branded web console** fetches the upstream [claw-ui](https://github.com/RantAI-dev/claw-ui)
on demand (into `~/.nqrust/web-ui`) and layers the NQRust brand (light/orange, **NQ·Rust** wordmark)
from `web-ui-theme/` on top at every launch via `scripts/apply-theme.sh` — so it survives upstream
changing its own brand.
(It's the **agent's** console — distinct from the MicroVM product's own Web UI served on a target
host's `:3000`.)

**One command (from anywhere):**
```bash
./web-ui.sh        # fetch + brand + deps + start → http://localhost:3939
./web-ui.sh stop   # stop console + gateway
```

**What it does under the hood** (all run for you by `web-ui.sh`, against `~/.nqrust/web-ui`):
```bash
rantaiclaw ui install --dir ~/.nqrust/web-ui   # fetch upstream claw-ui + deps (first run)
bash scripts/apply-theme.sh ~/.nqrust/web-ui   # layer the NQRust brand on top
rantaiclaw ui start --dir ~/.nqrust/web-ui      # starts gateway + console → http://localhost:3939
```

Notes:
- `rantaiclaw ui start` brings up **both the gateway and the console** — no separate `rantaiclaw gateway` step.
- **Don't** run `rantaiclaw ui install` or `ui start` *without* `--dir` — those use the plain upstream console at `~/.rantaiclaw/ui`, not your NQRust one at `~/.nqrust/web-ui`. `web-ui.sh` always passes `--dir`.
- `apply-theme.sh` is idempotent — `web-ui.sh` re-applies the brand on every launch (after pulling a newer upstream). For the plain upstream look, set `NEXT_PUBLIC_BRAND=rantaiclaw`.

## What's in here

```
skill/nqrust-microvm/          # MicroVM install playbook + scripts (drive the nqr-installer TUI)
skill/nqrust-microvm-operate/  # MicroVM day-2 ops playbook (nqvm CLI) + ensure-nqvm
skill/nqrust-hypervisor/       # Hypervisor (HCI) ops playbook (kubectl reference + recipes)
skill/nqrust-suite/            # Analytics + Identity Portal: install/Q&A/troubleshoot (SKILL.md, RUNBOOK.md, reference/, scripts/)
tutorials/                     # per-product hands-on walkthroughs (microvm.md, hypervisor.md, suite.md)
web-ui-theme/                  # NQRust brand overlay (fetched to ~/.nqrust/web-ui at launch)
scripts/apply-theme.sh         # layer the NQRust brand onto the fetched console (internal helper)
install.sh                     # deploy the skills + stage nqvm
web-ui.sh                      # one-command launcher for the NQRust web console
get.sh                         # online installer (downloads the prebuilt bundle)
bin/nqrust-install             # thin convenience wrapper (MicroVM install)
release/                       # build-bundle.sh + bundle files (QUICKSTART, setup.sh)
```

## Troubleshooting

- **MicroVM** — see `skill/nqrust-microvm/RUNBOOK.md` (auth, "no tmux session", host-key changes,
  long Build/Base-Image phases, rollback `nqr-installer uninstall --non-interactive --force`).
- **Hypervisor** — see the gotchas in [tutorials/hypervisor.md](tutorials/hypervisor.md) and the
  troubleshooting section of `skill/nqrust-hypervisor/SKILL.md`.
- **Suite (Analytics / Portal)** — see `skill/nqrust-suite/RUNBOOK.md` (GHCR `unauthorized`, port
  conflicts, the `role "analytics" does not exist` Postgres-init gotcha, Document RAG callbacks,
  Qdrant 409, Portal OAuth redirect mismatch, Identity not healthy, self-signed cert warning).
- **Web console** — run it from the repo root with `./web-ui.sh`; don't use `rantaiclaw ui install`
  (that fetches the plain upstream console). See *Web console* above.
