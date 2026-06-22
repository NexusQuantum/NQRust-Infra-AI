#!/usr/bin/env bash
# Launch the NQRust web console — one command, from ANY directory, no git clone needed.
#   nqrust-web         # fetch/update claw-ui (latest) + brand + start
#   nqrust-web stop    # stop the console + gateway
#
# The console (claw-ui) is NOT pinned: it follows upstream latest via `rantaiclaw ui
# install`, which clones it (or pulls --ff-only) and auto-installs bun + deps. The
# NQRust brand is layered on top each launch by scripts/apply-theme.sh (idempotent).
# Compatibility between the binary and claw-ui is maintained upstream by RantAI.
#
# Layout (identical in the repo and when staged to ~/.nqrust by get.sh):
#   <HERE>/web-ui.sh  <HERE>/scripts/apply-theme.sh  <HERE>/web-ui-theme/  <HERE>/VERSION
# claw-ui itself is fetched to ~/.nqrust/web-ui (override with NQRUST_UI_DIR).
set -euo pipefail
# Resolve through symlinks: nqrust-web is symlinked into ~/.local/bin → ~/.nqrust/web-ui.sh,
# so BASH_SOURCE is the symlink. Follow it so scripts/ + web-ui-theme/ + VERSION resolve.
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  _d="$(cd -P "$(dirname "$SELF")" && pwd)"; SELF="$(readlink "$SELF")"
  case "$SELF" in /*) ;; *) SELF="$_d/$SELF" ;; esac
done
HERE="$(cd -P "$(dirname "$SELF")" && pwd)"
UIDIR="${NQRUST_UI_DIR:-$HOME/.nqrust/web-ui}"
PORT="${NQRUST_UI_PORT:-3939}"
REPO="NexusQuantum/NQRust-Infra-AI"

say() { printf '%s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
# True if something is listening on 127.0.0.1:$1 (bash /dev/tcp — no nc/ss needed).
port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&- 3<&-; return 0; }; return 1; }

case "${1:-up}" in
  stop) say "→ stopping NQRust console…"; rantaiclaw ui stop --dir "$UIDIR"; exit 0 ;;
  up|"") ;;
  *) say "usage: $0 [up|stop]"; exit 2 ;;
esac

# --- tooling -------------------------------------------------------------------
command -v rantaiclaw >/dev/null 2>&1 || {
  warn "rantaiclaw not on PATH — open a new terminal or add ~/.local/bin to PATH"; exit 1; }
command -v git >/dev/null 2>&1 || {
  warn "git is required to fetch the web console — install git and retry"; exit 1; }
command -v bun >/dev/null 2>&1 || command -v npm >/dev/null 2>&1 || \
  say "! no bun/npm found — rantaiclaw will try to auto-install bun (needs curl + unzip)"

say "NQRust-Infra-AI · web console"
say "  rantaiclaw $(rantaiclaw --version 2>/dev/null | awk '{print $2}')"

# --- update notice (best-effort; never blocks) --------------------------------
if command -v curl >/dev/null 2>&1; then
  INST="$(grep -m1 '^bundle=' "$HERE/VERSION" 2>/dev/null | cut -d= -f2 || true)"
  LATEST="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null | sed 's#.*/tag/##' || true)"
  if [ -n "$INST" ] && [ -n "$LATEST" ] && [ "$INST" != "$LATEST" ] && \
     [ "$(printf '%s\n%s\n' "$INST" "$LATEST" | sort -V | tail -1)" = "$LATEST" ]; then
    say "  ↑ NQRust $LATEST tersedia (terpasang $INST) — perbarui dengan: nqrust-update"
  fi
fi

# --- 1. fetch / update claw-ui (follow latest) --------------------------------
# Our skin edits tracked files in the checkout; revert them first so `ui install`'s
# `git pull --ff-only` runs on a clean tree (otherwise the 2nd launch fails).
if [ -d "$UIDIR/.git" ]; then
  git -C "$UIDIR" checkout -- . 2>/dev/null || true
fi
say "→ fetching / updating console (claw-ui, latest)…"
rantaiclaw ui install --dir "$UIDIR"
say "  claw-ui @ $(git -C "$UIDIR" rev-parse --short HEAD 2>/dev/null || echo '?')"

# --- 2. layer the NQRust brand (warn + continue if upstream shifted) ----------
bash "$HERE/scripts/apply-theme.sh" "$UIDIR" || true

# --- 3. take over :$PORT if another console is already serving there ----------
# `rantaiclaw ui start` no-ops when the port is busy, so an existing (e.g. upstream-
# branded) console on this port would keep showing instead of our themed one.
if port_busy "$PORT"; then
  warn "a console is already running on :$PORT — taking it over for the NQRust-branded one"
  rantaiclaw ui stop >/dev/null 2>&1 || true            # default dir (~/.rantaiclaw/ui)
  rantaiclaw ui stop --dir "$UIDIR" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do port_busy "$PORT" || break; sleep 1; done
  if port_busy "$PORT"; then                            # still up → free the port directly
    if command -v fuser >/dev/null 2>&1; then fuser -k "${PORT}/tcp" >/dev/null 2>&1 || true
    elif command -v lsof  >/dev/null 2>&1; then kill $(lsof -ti "tcp:${PORT}" 2>/dev/null) 2>/dev/null || true
    fi
    for _ in 1 2 3 4 5; do port_busy "$PORT" || break; sleep 1; done
  fi
  port_busy "$PORT" && warn "could not free :$PORT — stop the other console, then re-run nqrust-web" || true
fi

# --- 4. start -----------------------------------------------------------------
say "→ starting console + gateway…"
rantaiclaw ui start --dir "$UIDIR" --port "$PORT"
say ""
say "✓ NQRust console → http://localhost:3939     (stop with:  $0 stop)"
