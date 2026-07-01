#!/usr/bin/env bash
# Airgapped installer — installs EVERYTHING from this bundle, no network:
# rantaiclaw binary + skills + nqvm + the web console (claw-ui prebuilt with node_modules)
# + a bundled bun runtime. Use on a restricted host that can't reach GitHub/npm/bun.sh.
#
# Usage: ./setup-airgapped.sh            (BINDIR= to change install dir; RANTAICLAW_PROFILE=)
#        NONINTERACTIVE=1 ./setup-airgapped.sh   (skip the onboarding prompt)
set -euo pipefail
say() { printf '%s\n' "$*"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${BINDIR:-$HOME/.local/bin}"
PROFILE="${RANTAICLAW_PROFILE:-default}"
NQDIR="$HOME/.nqrust"

say "NQRust-Infra-AI · airgapped installer"
say ""

# 1. bundled binary runs here?
"$HERE/bin/rantaiclaw" --version >/dev/null 2>&1 || {
  say "✗ bundled rantaiclaw won't run here — this bundle is $(grep -m1 ^arch= "$HERE/VERSION" 2>/dev/null | cut -d= -f2)"; exit 1; }
grep -acF "Secure SSH transport to a remote host" "$HERE/bin/rantaiclaw" >/dev/null || {
  say "✗ binary missing the remote-install tools — bad bundle"; exit 1; }
mkdir -p "$DEST"
install -m755 "$HERE/bin/rantaiclaw" "$DEST/rantaiclaw"
say "✓ rantaiclaw $("$HERE/bin/rantaiclaw" --version | awk '{print $2}') → $DEST/rantaiclaw"
case ":$PATH:" in *":$DEST:"*) ;; *) say "  ⚠ $DEST not on PATH — add: export PATH=\"$DEST:\$PATH\"" ;; esac

# 2. bundled bun runtime (the web console needs a JS runtime; airgapped can't fetch one)
if [ -x "$HERE/bun/bun" ] && ! command -v bun >/dev/null 2>&1 && ! command -v npm >/dev/null 2>&1; then
  install -m755 "$HERE/bun/bun" "$DEST/bun"
  say "✓ bun → $DEST/bun"
fi

# 3. LLM key (local prompt; no network). Airgapped case A still reaches the LLM API by key.
CFG="$HOME/.rantaiclaw/profiles/$PROFILE/config.toml"
if [ -f "$CFG" ]; then
  say "✓ existing config: $CFG (left as-is)"
elif [ -n "${NONINTERACTIVE:-}" ]; then
  say "→ configure a provider/key later:  rantaiclaw onboard   (or export OPENROUTER_API_KEY=…)"
else
  say "→ launching 'rantaiclaw onboard' (Ctrl-C to skip)…"
  "$DEST/rantaiclaw" onboard </dev/tty || say "! onboard skipped — set a provider/key before use"
fi

# 4. skills (+ bundled nqvm)
SK="$HOME/.rantaiclaw/profiles/$PROFILE/workspace/skills"
N=0
for d in "$HERE"/skill/*/; do
  s="$(basename "$d")"; N=$((N+1))
  rm -rf "$SK/$s"; mkdir -p "$SK/$s"; cp -r "$HERE/skill/$s/." "$SK/$s/"   # clean replace
  chmod +x "$SK/$s"/scripts/*.sh 2>/dev/null || true
done
say "✓ $N skills deployed → $SK"

# 5. web console: launcher + theme + PREBUILT claw-ui (with node_modules) → offline nqrust-web
mkdir -p "$NQDIR"
install -m755 "$HERE/web-ui.sh" "$NQDIR/.web-ui.sh.$$" && mv -f "$NQDIR/.web-ui.sh.$$" "$NQDIR/web-ui.sh"
mkdir -p "$NQDIR/scripts"; cp "$HERE/scripts/apply-theme.sh" "$NQDIR/scripts/apply-theme.sh"
rm -rf "$NQDIR/web-ui-theme"; cp -r "$HERE/web-ui-theme" "$NQDIR/web-ui-theme"
[ -f "$HERE/VERSION" ] && cp "$HERE/VERSION" "$NQDIR/VERSION"
chmod +x "$NQDIR/web-ui.sh" "$NQDIR/scripts/apply-theme.sh"
ln -sf "$NQDIR/web-ui.sh" "$DEST/nqrust-web"
if [ -f "$HERE/nqrust-uninstall" ]; then
  install -m755 "$HERE/nqrust-uninstall" "$NQDIR/nqrust-uninstall"
  ln -sf "$NQDIR/nqrust-uninstall" "$DEST/nqrust-uninstall"
fi
if [ -d "$HERE/web-ui/src" ] && [ -d "$HERE/web-ui/node_modules" ]; then
  rm -rf "$NQDIR/web-ui"; cp -r "$HERE/web-ui" "$NQDIR/web-ui"
  : > "$NQDIR/offline"                      # marker → nqrust-web runs offline (skips fetch)
  say "✓ web console (prebuilt, offline) → run: nqrust-web"
else
  say "! web console prebuilt files missing — nqrust-web will need network to fetch claw-ui"
fi

# 6. an airgapped `nqrust-update` that explains the offline update flow (no network fetch)
cat > "$DEST/.nqrust-update.$$" <<'UPD'
#!/usr/bin/env sh
cat >&2 <<'MSG'
✗ Airgapped install — there is no online update here.
  To update, re-install from a newer bundle:
    1. On a machine with internet, download a newer nqrust-airgapped-<version> bundle:
       https://github.com/NexusQuantum/NQRust-Infra-AI/releases
    2. Transfer it to this host and extract it.
    3. Run ./setup-airgapped.sh from the extracted folder.
MSG
exit 1
UPD
chmod +x "$DEST/.nqrust-update.$$"; mv -f "$DEST/.nqrust-update.$$" "$DEST/nqrust-update"
say "✓ nqrust-update → prints the offline update steps"

say ""
say "Done (airgapped). Next:"
say "  rantaiclaw chat        # CLI agent"
say "  nqrust-web             # web console → http://localhost:3939  (offline)"
say "  # updates: bring a newer nqrust-airgapped bundle, re-run ./setup-airgapped.sh"
