#!/usr/bin/env bash
# Apply the NQRust brand overlay onto the upstream claw-ui checkout (web-ui/).
#
# The overlay lives in web-ui-theme/ (owned by THIS repo). claw-ui is NOT pinned —
# it follows upstream latest — so this script is WARN+CONTINUE: if upstream moved a
# file we patch, it prints a loud warning and keeps going rather than aborting the
# launch. The primary brand (branding.ts overwrite) almost always applies; only
# secondary accents (the "nexus" literal, CSS) can degrade. Idempotent.
#
# Usage: scripts/apply-theme.sh [web-ui-dir]   (default: <repo>/web-ui)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBUI="${1:-$HERE/web-ui}"
THEME="$HERE/web-ui-theme"

ok()   { printf '%s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
ISSUES=0

# Hard prerequisite: a checkout must exist (else the clone/fetch failed upstream).
[ -d "$WEBUI/src" ] || { warn "claw-ui not checked out at $WEBUI — cannot apply brand"; exit 1; }

# 1. branding.ts → NQRust as the default brand (the PRIMARY skin; should always apply)
if [ -d "$WEBUI/src/lib" ]; then
  install -m644 "$THEME/branding.ts" "$WEBUI/src/lib/branding.ts"
else
  warn "src/lib/ missing — upstream moved branding.ts; NQRust brand may not apply"; ISSUES=$((ISSUES+1))
fi

# 2. brand mark (kept in web-ui-theme/ in case upstream drops it)
if [ -d "$WEBUI/public" ]; then
  install -m644 "$THEME/nqrust-mark.svg" "$WEBUI/public/nqrust-mark.svg"
else
  warn "public/ missing — brand logo not installed"; ISSUES=$((ISSUES+1))
fi

# 2b. Brand-aware code checks the id as a string (e.g. brand.id === "nexus"); our id is
#     "nqrust", so rename those literals. No-op (with a warning) if upstream changed the id.
MATCHES="$(grep -rl '"nexus"' "$WEBUI/src" --include='*.ts' --include='*.tsx' 2>/dev/null || true)"
if [ -n "$MATCHES" ]; then
  printf '%s\n' "$MATCHES" | while IFS= read -r f; do
    [ -n "$f" ] && sed -i 's/"nexus"/"nqrust"/g' "$f"
  done
else
  warn "brand id literal \"nexus\" not found — accent palette may fall back (upstream changed it)"; ISSUES=$((ISSUES+1))
fi

# 3. append the data-brand="nqrust" CSS block to globals.css (once)
GCSS="$WEBUI/src/app/globals.css"
if [ -f "$GCSS" ]; then
  if grep -q 'NQRUST-THEME' "$GCSS"; then :; else
    printf '\n' >> "$GCSS"; cat "$THEME/nqrust.css" >> "$GCSS"
  fi
else
  warn "globals.css not at expected path — NQRust CSS not applied"; ISSUES=$((ISSUES+1))
fi

if [ "$ISSUES" -eq 0 ]; then
  ok "✓ NQRust brand applied → $WEBUI"
else
  warn "NQRust brand applied PARTIALLY ($ISSUES issue(s)) — upstream claw-ui likely changed structure."
  warn "  The console still starts; branding may be incomplete. Run 'nqrust-update' or report it so we ship a fix."
fi
exit 0   # never block the launch
