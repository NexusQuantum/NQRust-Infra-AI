#!/usr/bin/env bash
# nqrust-suite · fetch a prebuilt airgapped installer binary from GitHub Releases.
# No build machine needed — the release already ships the self-extracting binary.
# Usage: fetch-airgapped.sh <analytics|portal> [version] [dest-dir]
#   version: a tag like v0.1.49, or omitted/"latest" to auto-detect the newest release.
#   dest-dir: where to save (default: current dir).
# Downloads the binary + its .sha256, verifies the checksum, and prints the path.
# Needs internet ON THE MACHINE THAT RUNS THIS (the build/staging box). The airgapped
# TARGET needs nothing — you transfer the verified binary to it. Safe to re-run.
set -u
PRODUCT="${1:-}"
VERSION="${2:-latest}"
DEST="${3:-.}"

case "$PRODUCT" in
  analytics) REPO="NexusQuantum/installer-NQRust-Analytics"; BASE="nqrust-analytics-airgapped-installer" ;;
  portal)    REPO="IdhamTryCode/installer-NQRust-Portal";    BASE="nqrust-portal-airgapped-installer" ;;
  *) echo "usage: fetch-airgapped.sh <analytics|portal> [version] [dest-dir]" >&2; exit 2 ;;
esac
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

# Resolve the tag. "latest" → ask the GitHub API for the newest release tag.
if [ "$VERSION" = "latest" ] || [ -z "$VERSION" ]; then
  TAG="$(curl -fsSL --max-time 20 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
         | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
  [ -n "$TAG" ] || { echo "could not resolve latest tag for ${REPO} (rate-limited? offline?)" >&2; exit 1; }
else
  TAG="$VERSION"
fi
VER="${TAG#v}"                                  # filename uses the version WITHOUT the leading v
FILE="${BASE}-${VER}-amd64"
URL="https://github.com/${REPO}/releases/download/${TAG}/${FILE}"

echo "product=${PRODUCT} repo=${REPO} tag=${TAG} file=${FILE}"
mkdir -p "$DEST"

echo "→ downloading checksum"
curl -fSL --retry 3 --max-time 60 -o "${DEST}/${FILE}.sha256" "${URL}.sha256" \
  || { echo "✗ failed to download ${URL}.sha256 (wrong version? asset missing?)" >&2; exit 1; }

echo "→ downloading binary (large — may take a while)"
curl -fSL --retry 3 -C - -o "${DEST}/${FILE}" "${URL}" \
  || { echo "✗ failed to download ${URL}" >&2; exit 1; }

echo "→ verifying checksum"
# The .sha256 typically contains "<hash>  <filename>"; verify by hash to be robust to path diffs.
EXPECTED="$(awk '{print $1}' "${DEST}/${FILE}.sha256")"
ACTUAL="$(sha256sum "${DEST}/${FILE}" | awk '{print $1}')"
if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ]; then
  chmod +x "${DEST}/${FILE}"
  echo "✓ OK  ${DEST}/${FILE}"
  echo "  sha256=${ACTUAL}"
  echo "  next on the TARGET: ./${FILE} install   (auto-extracts + loads images)"
else
  echo "✗ CHECKSUM MISMATCH — do NOT use this file. expected=${EXPECTED} actual=${ACTUAL}" >&2
  exit 1
fi
