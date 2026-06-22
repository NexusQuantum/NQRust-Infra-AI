#!/usr/bin/env bash
# nqrust-suite · live status — the GROUND TRUTH for Q&A and troubleshooting.
# Emits real container state + health probes. Answer questions ONLY from this
# output (never from memory). Usage: status.sh [analytics|portal|all]
# Run locally (shell) or remote (ssh exec). Reads nothing secret.
set -u
WHICH="${1:-all}"

has() { command -v "$1" >/dev/null 2>&1; }
if ! has docker; then echo "DOCKER=missing"; echo "(install Docker first)"; exit 0; fi

probe() { # probe <label> <url> — prints HTTP code or DOWN (self-signed ok via -k)
  local code
  code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "$2" 2>/dev/null)"
  [ -n "$code" ] && [ "$code" != "000" ] && echo "$1=$code" || echo "$1=DOWN"
}

show_ps() { # show_ps <name-regex>
  docker ps -a --filter "name=$1" \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null
}

if [ "$WHICH" = "analytics" ] || [ "$WHICH" = "all" ]; then
  echo "=== ANALYTICS — containers ==="
  show_ps 'analytics'
  echo "=== ANALYTICS — health ==="
  # UI port is configurable; default 3000. Engine 8080. AI service 5555.
  probe ANALYTICS_UI      "http://localhost:3000"
  probe ANALYTICS_ENGINE  "http://localhost:8080/healthz"
  probe ANALYTICS_AI      "http://localhost:5555/health"
  echo ""
fi

if [ "$WHICH" = "portal" ] || [ "$WHICH" = "all" ]; then
  echo "=== PORTAL/IDENTITY — containers ==="
  show_ps 'nqrust-'
  echo "=== PORTAL/IDENTITY — health ==="
  # Portal behind Traefik on PORTAL_PORT (default 8083), Identity on IDENTITY_PORT (8082).
  # Identity exposes /health/ready internally on 9000; via Traefik use the realm endpoint.
  probe PORTAL_HTTPS    "https://localhost:8083"
  probe IDENTITY_HTTPS  "https://localhost:8082/realms/master"
  echo ""
fi

echo "=== compose project state (if a .env / compose is in CWD) ==="
if has docker && docker compose version >/dev/null 2>&1 && [ -f docker-compose.yaml ]; then
  docker compose ps 2>/dev/null || echo "(no compose project in this directory)"
else
  echo "(run from the install dir to see compose ps, or use 'docker ps' above)"
fi
