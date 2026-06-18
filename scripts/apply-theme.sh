#!/usr/bin/env bash
# Apply the NQRust brand overlay onto the upstream claw-ui submodule (web-ui/).
#
# The overlay lives in web-ui-theme/ (owned by THIS repo) so the NQRust brand
# survives upstream removing its own brand. Idempotent — safe to re-run after
# `git submodule update` (which resets web-ui/ to a fresh upstream checkout).
#
# Usage: scripts/apply-theme.sh [web-ui-dir]   (default: <repo>/web-ui)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBUI="${1:-$HERE/web-ui}"
THEME="$HERE/web-ui-theme"

[ -d "$WEBUI/src" ] || {
  echo "✗ web-ui submodule not checked out at $WEBUI"
  echo "  run: git submodule update --init web-ui"
  exit 1
}

# 1. branding.ts → NQRust as the default brand
install -m644 "$THEME/branding.ts" "$WEBUI/src/lib/branding.ts"

# 2. brand mark (kept in web-ui-theme/ in case upstream drops it)
install -m644 "$THEME/nqrust-mark.svg" "$WEBUI/public/nqrust-mark.svg"

# 2b. Code that is brand-aware checks the id as a string (e.g. console.ts: `brand.id === "nexus"`).
#     Our brand id is "nqrust", so rename those literals to match — otherwise brand-conditional
#     logic (accent palettes, etc.) silently falls back. Idempotent.
for f in $(grep -rl '"nexus"' "$WEBUI/src" --include='*.ts' --include='*.tsx' 2>/dev/null); do
  sed -i 's/"nexus"/"nqrust"/g' "$f"
done

# 3. append the data-brand="nqrust" CSS block to globals.css (once)
GCSS="$WEBUI/src/app/globals.css"
if grep -q 'NQRUST-THEME' "$GCSS"; then
  echo "✓ NQRust CSS already present in globals.css"
else
  printf '\n' >> "$GCSS"
  cat "$THEME/nqrust.css" >> "$GCSS"
  echo "✓ appended NQRust CSS to globals.css"
fi

echo "✓ NQRust theme applied → $WEBUI (default brand: nqrust)"
echo "  start:  rantaiclaw ui start --dir \"$WEBUI\""
