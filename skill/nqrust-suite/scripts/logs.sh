#!/usr/bin/env bash
# nqrust-suite · fetch recent logs for troubleshooting. Quote the real output to
# the user; never invent log lines. Usage: logs.sh <container-name|service> [lines]
# e.g. logs.sh analytics-ui 200   ·   logs.sh nqrust-identity 200
set -u
NAME="${1:?usage: logs.sh <container|service> [lines]}"
LINES="${2:-150}"

has() { command -v "$1" >/dev/null 2>&1; }
has docker || { echo "docker not found"; exit 1; }

# Prefer an exact running/created container; fall back to compose service logs.
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "=== docker logs $NAME (last $LINES) ==="
  docker logs --tail "$LINES" "$NAME" 2>&1
elif docker compose version >/dev/null 2>&1 && [ -f docker-compose.yaml ]; then
  echo "=== docker compose logs $NAME (last $LINES) ==="
  docker compose logs --tail "$LINES" "$NAME" 2>&1
else
  echo "No container named '$NAME' and no compose project in CWD."
  echo "Running containers:"; docker ps --format '  {{.Names}}\t{{.Status}}'
fi
