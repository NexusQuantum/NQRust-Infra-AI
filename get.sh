#!/usr/bin/env bash
# Online installer for NQRust-Infra-AI. Downloads the latest release bundle (prebuilt static
# rantaiclaw with ssh+pty + the skills + the nqvm CLI), verifies its checksum, installs the
# binary, and deploys the skills. Non-interactive — safe to pipe:
#
#   curl -fsSL https://raw.githubusercontent.com/NexusQuantum/NQRust-Infra-AI/master/get.sh | bash
#
# It does NOT run onboard (that needs a terminal) — it prints the one command to run next.
# Env: NQR_AGENT_VERSION (default: latest) · BINDIR (default ~/.local/bin) · RANTAICLAW_PROFILE
#
# POSIX-sh safe: works whether piped to `sh` (dash on Debian/Ubuntu) or `bash`.
set -eu
# pipefail is a bash/zsh feature — enable it only where supported (no-op on dash).
(set -o pipefail) 2>/dev/null && set -o pipefail || true
# Quiet mode (NQR_QUIET=1) silences the ✓ progress lines — used by `nqrust-update`.
QUIET="${NQR_QUIET:-0}"
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

REPO="NexusQuantum/NQRust-Infra-AI"
VER="${NQR_AGENT_VERSION:-latest}"
PROFILE="${RANTAICLAW_PROFILE:-default}"
DEST="${BINDIR:-$HOME/.local/bin}"

OS="$(uname -s)"; ARCH="$(uname -m)"
[ "$OS" = "Linux" ]    || die "this bundle is Linux x86_64 only (got $OS). Build from source: https://github.com/$REPO"
[ "$ARCH" = "x86_64" ] || die "this bundle is x86_64 only (got $ARCH). Build from source: https://github.com/$REPO"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar  >/dev/null 2>&1 || die "tar is required"

# resolve the release tag (asset filename embeds the version)
if [ "$VER" = "latest" ]; then
  TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" | sed 's#.*/tag/##')"
  [ -n "$TAG" ] || die "could not resolve the latest release tag"
else
  TAG="$VER"
fi
ASSET="nqrust-infra-ai-${TAG}-x86_64-linux.tar.gz"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
say "→ downloading $ASSET …"
if [ "$QUIET" = 1 ]; then
  curl -fsSL -o "$TMP/b.tar.gz" "$URL" || die "download failed: $URL"
else
  curl -fSL --progress-bar -o "$TMP/b.tar.gz" "$URL" || die "download failed: $URL"
fi

# verify the checksum if the sidecar is published
if curl -fsSL -o "$TMP/b.sha256" "$URL.sha256" 2>/dev/null; then
  WANT="$(awk '{print $1}' "$TMP/b.sha256")"
  GOT="$(sha256sum "$TMP/b.tar.gz" | awk '{print $1}')"
  [ "$WANT" = "$GOT" ] || die "checksum mismatch (want $WANT, got $GOT) — aborting"
  say "✓ checksum verified"
fi

tar xzf "$TMP/b.tar.gz" -C "$TMP"
BDIR="$TMP/nqrust-infra-ai-${TAG}-x86_64-linux"
RC="$BDIR/bin/rantaiclaw"
[ -x "$RC" ] || die "bundle is missing the rantaiclaw binary"
"$RC" --version >/dev/null 2>&1 || die "the bundled rantaiclaw won't run on this host (arch/libc mismatch)"

# tools present? grep -a reads the binary directly — no dependency on `strings` (binutils, not always installed)
HAS="$(grep -acF "Secure SSH transport to a remote host" "$RC" || true)"
[ "${HAS:-0}" -ge 1 ] || die "the bundled binary lacks the remote-install (ssh+pty) tools"

# install the binary — but never silently downgrade a newer rantaiclaw already on PATH.
# Set NQR_FORCE=1 to install the bundled binary regardless.
NEW_VER="$("$RC" --version 2>/dev/null | awk '{print $2}')"
CUR_BIN="$(command -v rantaiclaw 2>/dev/null || true)"
CUR_VER=""; [ -n "$CUR_BIN" ] && CUR_VER="$("$CUR_BIN" --version 2>/dev/null | awk '{print $2}')"
mkdir -p "$DEST"
if [ "${NQR_FORCE:-0}" != "1" ] && [ -n "$CUR_VER" ] && [ "$CUR_VER" != "$NEW_VER" ] && \
   [ "$(printf '%s\n%s\n' "$CUR_VER" "$NEW_VER" | sort -V | tail -1)" = "$CUR_VER" ]; then
  say "✓ keeping existing rantaiclaw $CUR_VER ($CUR_BIN) — newer than bundled $NEW_VER"
  say "  (force the bundled build with: NQR_FORCE=1)"
else
  install -m755 "$RC" "$DEST/rantaiclaw"
  say "✓ installed rantaiclaw $NEW_VER → $DEST/rantaiclaw"
fi
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) say "  ⚠ $DEST is not on your PATH — add it:  export PATH=\"$DEST:\$PATH\"" ;;
esac

# deploy all bundled skills (incl. the bundled nqvm)
SK="$HOME/.rantaiclaw/profiles/$PROFILE/workspace/skills"
for d in "$BDIR"/skill/*/; do
  s="$(basename "$d")"
  mkdir -p "$SK/$s"
  cp -r "$d." "$SK/$s/"
  chmod +x "$SK/$s"/scripts/*.sh 2>/dev/null || true
done
say "✓ skills deployed → $SK"

# stage the web console (launcher + theme) so the browser UI works WITHOUT a git clone.
# This is lazy: no heavy fetch here — the first `nqrust-web` run clones claw-ui + installs deps.
if [ -f "$BDIR/web-ui.sh" ]; then
  command -v git >/dev/null 2>&1 || say "! git not found — needed by the web console (nqrust-web). Install git."
  NQDIR="$HOME/.nqrust"
  mkdir -p "$NQDIR/scripts"
  cp "$BDIR/web-ui.sh" "$NQDIR/web-ui.sh"
  cp "$BDIR/scripts/apply-theme.sh" "$NQDIR/scripts/apply-theme.sh"
  rm -rf "$NQDIR/web-ui-theme"; cp -r "$BDIR/web-ui-theme" "$NQDIR/web-ui-theme"
  [ -f "$BDIR/VERSION" ] && cp "$BDIR/VERSION" "$NQDIR/VERSION"
  chmod +x "$NQDIR/web-ui.sh" "$NQDIR/scripts/apply-theme.sh"
  ln -sf "$NQDIR/web-ui.sh" "$DEST/nqrust-web"
  cat > "$DEST/nqrust-update" <<'UPD'
#!/usr/bin/env sh
# Update NQRust to the latest: bundle (skills + web console + bundled binary) AND the
# rantaiclaw binary (latest upstream release you publish). Quiet — only essentials.
set -e
printf '→ updating NQRust…\n'
curl -fsSL https://raw.githubusercontent.com/NexusQuantum/NQRust-Infra-AI/master/get.sh | NQR_QUIET=1 sh
if command -v rantaiclaw >/dev/null 2>&1; then
  before="$(rantaiclaw --version 2>/dev/null | awk '{print $2}')"
  rantaiclaw update --yes >/dev/null 2>&1 || true
  after="$(rantaiclaw --version 2>/dev/null | awk '{print $2}')"
  if [ "$before" != "$after" ]; then printf '✓ rantaiclaw %s → %s\n' "$before" "$after"
  else printf '✓ rantaiclaw %s (latest)\n' "$after"; fi
fi
printf '✓ NQRust up to date\n'
UPD
  chmod +x "$DEST/nqrust-update"
  say "✓ web console ready → run: nqrust-web"
fi

PATHHINT=""; case ":$PATH:" in *":$DEST:"*) ;; *) PATHHINT="export PATH=\"$DEST:\$PATH\";  ";; esac
say ""
say "Ready:"
say "  ${PATHHINT}rantaiclaw onboard      # set LLM provider/key (once)"
say "  rantaiclaw chat                    # CLI agent"
say "  nqrust-web                         # web console → http://localhost:3939"
say "  nqrust-update                      # update everything later"
