#!/usr/bin/env bash
# Launch the NQRust web console — one command, no git clone.
#   nqrust-web         # fetch/update claw-ui (latest) + brand + start
#   nqrust-web stop    # stop the console + gateway
# Quiet by default; set NQRUST_VERBOSE=1 to see the full fetch/build output.
#
# The NQRust brand is laid over upstream claw-ui each launch by scripts/apply-theme.sh
# using files owned by this repo (web-ui-theme/) — no dependency on any upstream brand.
set -euo pipefail
# Follow the symlink (nqrust-web → ~/.nqrust/web-ui.sh) so scripts/ + web-ui-theme/ resolve.
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  _d="$(cd -P "$(dirname "$SELF")" && pwd)"; SELF="$(readlink "$SELF")"
  case "$SELF" in /*) ;; *) SELF="$_d/$SELF" ;; esac
done
HERE="$(cd -P "$(dirname "$SELF")" && pwd)"
UIDIR="${NQRUST_UI_DIR:-$HOME/.nqrust/web-ui}"
PORT="${NQRUST_UI_PORT:-3939}"
VERBOSE="${NQRUST_VERBOSE:-0}"
OFFLINE="${NQRUST_OFFLINE:-0}"   # airgapped: skip the online fetch, use a pre-provisioned $UIDIR
[ "$OFFLINE" != 1 ] && [ -f "$HOME/.nqrust/offline" ] && OFFLINE=1   # marker dropped by setup-airgapped.sh
LOG="$HOME/.nqrust/nqrust-web.log"
REPO="NexusQuantum/NQRust-Infra-AI"

say() { printf '%s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
# Run quietly (output → log) unless NQRUST_VERBOSE=1.
q() { if [ "$VERBOSE" = 1 ]; then "$@"; else "$@" >>"$LOG" 2>&1; fi; }
port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&- 3<&-; return 0; }; return 1; }

case "${1:-up}" in
  stop) rantaiclaw ui stop --dir "$UIDIR" >/dev/null 2>&1 && say "✓ stopped" || say "nothing to stop"; exit 0 ;;
  up|"") ;;
  *) say "usage: $0 [up|stop]"; exit 2 ;;
esac

command -v rantaiclaw >/dev/null 2>&1 || { warn "rantaiclaw not on PATH — open a new terminal"; exit 1; }
# git is only needed to fetch claw-ui online; offline uses the pre-provisioned checkout.
[ "$OFFLINE" = 1 ] || command -v git >/dev/null 2>&1 || { warn "git is required — install git and retry"; exit 1; }

mkdir -p "$HOME/.nqrust"; : >"$LOG"
say "NQRust web console (rantaiclaw $(rantaiclaw --version 2>/dev/null | awk '{print $2}'))"

# update notice (best-effort, 1 line)
if command -v curl >/dev/null 2>&1; then
  INST="$(grep -m1 '^bundle=' "$HERE/VERSION" 2>/dev/null | cut -d= -f2 || true)"
  LATEST="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null | sed 's#.*/tag/##' || true)"
  [ -n "$INST" ] && [ -n "$LATEST" ] && [ "$INST" != "$LATEST" ] && \
    [ "$(printf '%s\n%s\n' "$INST" "$LATEST" | sort -V | tail -1)" = "$LATEST" ] && \
    say "  ↑ $LATEST tersedia — jalankan: nqrust-update" || true
fi

# fetch / update claw-ui — unless offline (airgapped), where $UIDIR is pre-provisioned.
if [ "$OFFLINE" = 1 ]; then
  [ -d "$UIDIR/src" ] && [ -d "$UIDIR/node_modules" ] || {
    warn "NQRUST_OFFLINE=1 but $UIDIR is not provisioned — run the airgapped setup first"; exit 1; }
  say "  (offline: using pre-fetched claw-ui)"
else
  # revert our skin edits first so ff-pull stays clean
  [ -d "$UIDIR/.git" ] && git -C "$UIDIR" checkout -- . >/dev/null 2>&1 || true
  [ -d "$UIDIR/node_modules" ] || say "→ preparing console (first run: fetch + install, ~1 min)…"
  q rantaiclaw ui install --dir "$UIDIR" || { warn "fetch failed — see $LOG"; exit 1; }
fi

# lay on the NQRust brand — skip when offline (the airgapped bundle is already pre-branded)
[ "$OFFLINE" = 1 ] || bash "$HERE/scripts/apply-theme.sh" "$UIDIR" >>"$LOG" || true

# take over the port if another console holds it (ui start no-ops on a busy port)
if port_busy "$PORT"; then
  say "→ taking over :$PORT from an existing console…"
  rantaiclaw ui stop >/dev/null 2>&1 || true
  rantaiclaw ui stop --dir "$UIDIR" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do port_busy "$PORT" || break; sleep 1; done
  if port_busy "$PORT"; then
    if command -v fuser >/dev/null 2>&1; then fuser -k "${PORT}/tcp" >/dev/null 2>&1 || true
    elif command -v lsof  >/dev/null 2>&1; then kill $(lsof -ti "tcp:${PORT}" 2>/dev/null) 2>/dev/null || true; fi
    for _ in 1 2 3 4 5; do port_busy "$PORT" || break; sleep 1; done
  fi
  port_busy "$PORT" && { warn "could not free :$PORT — stop the other console, then re-run"; exit 1; } || true
fi

q rantaiclaw ui start --dir "$UIDIR" --port "$PORT" || { warn "start failed — see $LOG"; exit 1; }
say "✓ NQRust console → http://localhost:$PORT   (stop: nqrust-web stop)"
