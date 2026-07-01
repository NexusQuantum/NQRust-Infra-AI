# Airgapped (offline) installation

This guide covers installing and updating NQRust-Infra-AI on a **restricted host** (Linux x86_64)
that cannot reach GitHub, npm, or bun.sh. Everything ships pre-packaged, so **nothing is fetched**
during installation or at runtime.

**Prerequisite:** the agent still requires a reachable **LLM** — a cloud API accessed by key, or a
local/on-prem model on your network. This is the one component that cannot be bundled.

The examples use version **`v0.2.11`** and representative paths (`~/Downloads`, the home directory,
a USB mount). Replace the values marked `# CHANGE:` with your version, transfer location, and LLM
credentials. The latest version — and confirmation that it ships an `nqrust-airgapped-*` asset — is
listed at <https://github.com/NexusQuantum/NQRust-Infra-AI/releases>.

---

## Step 1 — On a machine WITH internet: download the bundle

```bash
VER=v0.2.11                                   # CHANGE: latest version with an airgapped asset
BASE=https://github.com/NexusQuantum/NQRust-Infra-AI/releases/download/$VER
FILE=nqrust-airgapped-$VER-x86_64-linux.tar.gz

cd ~/Downloads
curl -fLO "$BASE/$FILE"
curl -fLO "$BASE/$FILE.sha256"
sha256sum -c "$FILE.sha256"                    # must print: OK
```

## Step 2 — Transfer it to the airgapped host

Choose whichever method fits your environment.

```bash
# A) over SSH (if you can reach the host on the LAN):
scp ~/Downloads/nqrust-airgapped-v0.2.11-x86_64-linux.tar.gz  user@10.0.0.9:~/   # CHANGE: user@host

# B) via USB stick — copy on the connected machine:
cp ~/Downloads/nqrust-airgapped-v0.2.11-x86_64-linux.tar.gz  /media/$USER/MYUSB/  # CHANGE: USB path
#    then on the AIRGAPPED host, plug it in and:
cp /media/$USER/MYUSB/nqrust-airgapped-v0.2.11-x86_64-linux.tar.gz  ~/            # CHANGE: USB path
```

## Step 3 — On the airgapped host: install (no network)

```bash
cd ~
tar xzf nqrust-airgapped-v0.2.11-x86_64-linux.tar.gz
cd nqrust-airgapped-v0.2.11-x86_64-linux
./setup-airgapped.sh                           # installs rantaiclaw + skills + nqvm + bun + prebuilt web console

# make sure the commands are on PATH (only if setup warned about it):
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# point it at your LLM (reachable endpoint required):
export OPENROUTER_API_KEY="sk-xxxxxxxx"        # CHANGE: your key
echo 'export OPENROUTER_API_KEY="sk-xxxxxxxx"' >> ~/.bashrc   # CHANGE: your key
#   …or for a LOCAL model, run `rantaiclaw onboard` and pick your endpoint,
#   or edit ~/.rantaiclaw/config.toml (set default_provider + base_url + api_key).
```

## Step 4 — Use it

```bash
rantaiclaw chat                                # CLI agent
# web console (offline — uses the prebuilt console, no fetch):
nqrust-web                                     # → open http://localhost:3939
nqrust-web stop                                # stop it
```

## Step 5 — Update later (offline = re-download)

There is **no online update** on an airgapped host — you download a newer bundle and re-install.
`nqrust-update` / `rantaiclaw update` are online-only.

```bash
# On the CONNECTED machine — download the newer bundle:
NEW=v0.2.12                                     # CHANGE: the newer version
BASE=https://github.com/NexusQuantum/NQRust-Infra-AI/releases/download/$NEW
cd ~/Downloads
curl -fLO "$BASE/nqrust-airgapped-$NEW-x86_64-linux.tar.gz"
curl -fLO "$BASE/nqrust-airgapped-$NEW-x86_64-linux.tar.gz.sha256"
sha256sum -c "nqrust-airgapped-$NEW-x86_64-linux.tar.gz.sha256"

# …transfer as in Step 2, then on the AIRGAPPED host:
cd ~
tar xzf nqrust-airgapped-v0.2.12-x86_64-linux.tar.gz          # CHANGE: version
cd nqrust-airgapped-v0.2.12-x86_64-linux                      # CHANGE: version
./setup-airgapped.sh                            # replaces binary + skills + web console
```

---

## Notes and requirements

- **Same architecture.** The bundle is **Linux x86_64**; the prebuilt `node_modules` + `bun` must
  match the target arch. Don't build it on ARM/macOS for an x86_64 target.
- **LLM is the one thing that can't be bundled.** Airgapped without any reachable model/API = the
  agent can't think. Have a local model (Ollama/vLLM/llama.cpp) or an internal API endpoint.
- **Web console port.** Default `http://localhost:3939`. Change with `NQRUST_UI_PORT=3940 nqrust-web`.
- **Force online fetch off explicitly** (e.g. if you provisioned `~/.nqrust/web-ui` by hand):
  `NQRUST_OFFLINE=1 nqrust-web`. (`setup-airgapped.sh` sets this automatically via `~/.nqrust/offline`.)
- **Rebuild the bundle yourself** on a connected same-arch host:
  `release/pack-airgapped.sh <path-to-rantaiclaw-binary> v0.2.11`.
