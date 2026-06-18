#!/usr/bin/env bash
# Launch the NQRust web console — one command, from ANY directory.
#   ./web-ui.sh        # fetch (if needed) + brand + install deps + start
#   ./web-ui.sh stop   # stop the console + gateway
#
# Resolves the repo root absolutely and passes an absolute --dir to `rantaiclaw ui start`,
# so it never lands on the wrong path (e.g. web-ui/web-ui) regardless of your current dir.
# It also avoids `rantaiclaw ui install`, which fetches the plain upstream console into
# ~/.rantaiclaw/ui instead of your NQRust-branded web-ui/.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBUI="$HERE/web-ui"

say() { printf '%s\n' "$*"; }

case "${1:-up}" in
  stop) say "→ stopping NQRust console…"; rantaiclaw ui stop --dir "$WEBUI"; exit 0 ;;
  up|"") ;;
  *) say "usage: $0 [up|stop]"; exit 2 ;;
esac

say "NQRust-Infra-AI · web console"
say ""

# tooling
command -v rantaiclaw >/dev/null 2>&1 || {
  say "✗ rantaiclaw not on PATH — run:  source ~/.cargo/env   (or open a new terminal)"; exit 1; }
command -v bun >/dev/null 2>&1 || command -v npm >/dev/null 2>&1 || {
  say "✗ need a JavaScript runtime — install bun (https://bun.sh) or npm"; exit 1; }

# 1. fetch the console submodule if it isn't checked out yet
if [ ! -d "$WEBUI/src" ]; then
  say "→ fetching web-ui…"
  git -C "$HERE" submodule update --init web-ui >/dev/null 2>&1
fi

# 2. layer the NQRust brand on top of upstream (idempotent)
bash "$HERE/scripts/apply-theme.sh" "$WEBUI" >/dev/null
say "✓ NQRust brand applied"

# 3. install deps if missing
if [ ! -d "$WEBUI/node_modules" ]; then
  say "→ installing console deps…"
  if command -v bun >/dev/null 2>&1; then (cd "$WEBUI" && bun install >/dev/null); else (cd "$WEBUI" && npm install >/dev/null); fi
  say "✓ deps installed"
else
  say "✓ deps present"
fi

# 4. start — absolute --dir, so the current directory never matters
say "→ starting console + gateway…"
rantaiclaw ui start --dir "$WEBUI"
say ""
say "✓ NQRust console → http://localhost:3939     (stop with:  $0 stop)"
