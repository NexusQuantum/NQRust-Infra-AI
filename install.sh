#!/usr/bin/env bash
# Install NQRust-Infra-AI into your local RantaiClaw — deploy the skills, stage the nqvm
# CLI, and brand the optional web console.  Usage: ./install.sh [profile]   (default: "default")
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '%s\n' "$*"; }

say "NQRust-Infra-AI · installer"
say ""

# 1. RantaiClaw present?
if ! command -v rantaiclaw >/dev/null 2>&1; then
  say "✗ rantaiclaw not found on PATH"
  say "    install a RantaiClaw build with the remote-install tools (ssh + pty)"
  say "    see README.md → 'Getting a RantaiClaw with the tools'"
  exit 1
fi
say "✓ rantaiclaw $(rantaiclaw --version | awk '{print $2}')"

# 2. Are the ssh + pty tools compiled into this binary? (the microvm skills need them)
BIN="$(command -v rantaiclaw)"
# grep -a reads the binary directly — no dependency on `strings` (binutils, not always installed).
HAS_TOOLS="$(grep -acF "Secure SSH transport to a remote host" "$BIN" || true)"
if [ "${HAS_TOOLS:-0}" -eq 0 ]; then
  say "✗ this rantaiclaw lacks the remote-install tools (ssh + pty)"
  say "    rebuild:  cargo build --release --features remote-install"
  say "    (or install a release that bundles them — see README.md)"
  exit 1
fi
say "✓ remote-install tools (ssh + pty) present"

# 2b. Stage the nqvm CLI for the operate skill (NOT a published release asset yet, so the agent
#     pushes this bundled binary to target hosts). Best-effort — needs NQRust-MicroVM source + cargo.
if [ ! -x "$HERE/skill/nqrust-microvm-operate/bin/nqvm" ]; then
  say "→ staging nqvm (operate skill, best-effort)…"
  if bash "$HERE/skill/nqrust-microvm-operate/scripts/build-nqvm.sh" >/dev/null 2>&1; then
    say "✓ nqvm staged"
  else
    say "! nqvm not staged (no source/cargo) — the operate skill builds/pushes it on demand"
  fi
else
  say "✓ nqvm already staged"
fi

# 2c. kubectl for the nqrust-hypervisor skill — it drives a Hypervisor cluster locally over
#     kubectl (not over SSH). Soft check: only matters once you have a cluster, so warn, don't fail.
if command -v kubectl >/dev/null 2>&1; then
  say "✓ kubectl present — nqrust-hypervisor can drive a Hypervisor cluster"
else
  say "! kubectl not found — needed by nqrust-hypervisor (drives a cluster via kubeconfig)"
  say "    install kubectl, then drop a kubeconfig at the workspace as 'kubeconfig-hypervisor'"
fi

# 3. Deploy the skills into the active profile's workspace
#    nqrust-microvm          → install (drive the installer TUI)
#    nqrust-microvm-operate  → day-2 ops via the nqvm CLI
#    nqrust-hypervisor       → day-2 ops for a Hypervisor (HCI) cluster via kubectl
#    nqrust-suite            → install/Q&A/troubleshoot NQRust Analytics + Identity Portal
ROOT="${RANTAICLAW_HOME:-$HOME/.rantaiclaw}"
PROFILE="${1:-${RANTAICLAW_PROFILE:-default}}"
SKILLS_DIR="$ROOT/profiles/$PROFILE/workspace/skills"
SKILLS="nqrust-microvm nqrust-microvm-operate nqrust-hypervisor nqrust-suite"
say "→ deploying skills (profile: $PROFILE)…"
for s in $SKILLS; do
  DEST="$SKILLS_DIR/$s"
  mkdir -p "$DEST"
  cp -r "$HERE/skill/$s/." "$DEST/"
  chmod +x "$DEST"/scripts/*.sh 2>/dev/null || true
  say "  ✓ $s"
done

# 4. Confirm they load
WANT="$(set -- $SKILLS; echo $#)"
LOADED="$(rantaiclaw skills list 2>/dev/null | grep -ci nqrust || true)"
if [ "${LOADED:-0}" -ge "$WANT" ]; then
  say "✓ all $WANT skills loaded"
elif [ "${LOADED:-0}" -gt 0 ]; then
  say "! $LOADED of $WANT skills loaded — re-check 'rantaiclaw skills list'"
else
  say "! skills copied but not listed — is profile '$PROFILE' the active one?"
fi

# 5. Link the convenience wrapper onto PATH if ~/.local/bin exists
if [ -d "$HOME/.local/bin" ]; then
  ln -sf "$HERE/bin/nqrust-install" "$HOME/.local/bin/nqrust-install"
  say "✓ wrapper linked → ~/.local/bin/nqrust-install"
fi

# 6. Brand the optional web console (claw-ui). Upstream is vendored as the `web-ui/` submodule;
#    the NQRust brand lives in web-ui-theme/ and is layered on by scripts/apply-theme.sh.
if [ -f "$HERE/.gitmodules" ] && grep -q '"web-ui"' "$HERE/.gitmodules" 2>/dev/null; then
  git -C "$HERE" submodule update --init web-ui >/dev/null 2>&1 || true
  if [ -d "$HERE/web-ui/src" ]; then
    bash "$HERE/scripts/apply-theme.sh" "$HERE/web-ui" >/dev/null && say "✓ web console branded (NQRust)"
  else
    say "! web-ui submodule not checked out — run: git submodule update --init web-ui"
  fi
fi

say ""
say "Done. Next:"
say "  rantaiclaw onboard   # set your LLM provider + key (if you haven't)"
say "  ./web-ui.sh          # launch the NQRust web console → http://localhost:3939"
say ""
say "  # install a MicroVM host:"
say "  nqrust-install \"on 10.0.0.5, ssh user ubuntu, key ~/.ssh/id_ed25519, NAT\""
say "  # operate a Hypervisor cluster (after a kubeconfig is in the workspace):"
say "  rantaiclaw agent -m \"list all VMs on the Hypervisor cluster\""
