#!/usr/bin/env bash
# nqrust-suite · target discovery — emits a KEY=VALUE block the skill parses to
# decide install method (deb/source/airgap), warn on blockers, and recommend.
# Works the same whether run locally (shell tool) or on a remote host (ssh exec).
# Never prints secrets. Safe to re-run.
set -u

emit() { printf '%s=%s\n' "$1" "$2"; }
has()  { command -v "$1" >/dev/null 2>&1; }

echo "=== DISCOVERY ==="

# --- OS / arch ---------------------------------------------------------------
emit OS_ARCH "$(uname -m 2>/dev/null || echo unknown)"
if [ -r /etc/os-release ]; then
  . /etc/os-release
  emit OS_ID "${ID:-unknown}"
  emit OS_VERSION "${VERSION_ID:-unknown}"
  emit OS_PRETTY "${PRETTY_NAME:-unknown}"
else
  emit OS_ID unknown; emit OS_VERSION unknown; emit OS_PRETTY unknown
fi

# --- Docker stack ------------------------------------------------------------
if has docker; then
  emit DOCKER present
  emit DOCKER_VERSION "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
  # daemon reachable?
  if docker info >/dev/null 2>&1; then emit DOCKER_DAEMON up; else emit DOCKER_DAEMON down; fi
  # compose v2 (plugin) vs legacy
  if docker compose version >/dev/null 2>&1; then emit COMPOSE v2
  elif has docker-compose;          then emit COMPOSE legacy
  else                                   emit COMPOSE missing; fi
  if docker buildx version >/dev/null 2>&1; then emit BUILDX present; else emit BUILDX missing; fi
else
  emit DOCKER missing; emit DOCKER_DAEMON down; emit COMPOSE missing; emit BUILDX missing
fi

# --- GHCR auth (does ~/.docker/config.json mention ghcr.io? — never print creds) ---
if [ -r "${HOME}/.docker/config.json" ] && grep -q 'ghcr.io' "${HOME}/.docker/config.json" 2>/dev/null; then
  emit GHCR_LOGIN present
else
  emit GHCR_LOGIN absent
fi

# --- connectivity (airgap detection) -----------------------------------------
if has curl && curl -fsS --max-time 5 https://ghcr.io/v2/ >/dev/null 2>&1; then
  emit GHCR_REACHABLE yes
elif has curl && curl -fsS --max-time 5 https://github.com >/dev/null 2>&1; then
  emit GHCR_REACHABLE partial   # github ok, registry probe failed
else
  emit GHCR_REACHABLE no        # likely airgapped → recommend airgapped install
fi

# --- product binaries already installed? -------------------------------------
has nqrust-analytics && emit NQRUST_ANALYTICS_BIN present || emit NQRUST_ANALYTICS_BIN absent
has nqrust-portal     && emit NQRUST_PORTAL_BIN present     || emit NQRUST_PORTAL_BIN absent

# --- existing stacks running? (so we don't blindly reinstall) ----------------
if has docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -q .; then
  RUN="$(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
  emit RUNNING_CONTAINERS "${RUN:-none}"
  echo "$RUN" | grep -qE 'analytics-(ui|engine|service)' && emit ANALYTICS_STACK running || emit ANALYTICS_STACK absent
  echo "$RUN" | grep -qE 'nqrust-(identity|traefik)'      && emit PORTAL_STACK running     || emit PORTAL_STACK absent
else
  emit RUNNING_CONTAINERS none; emit ANALYTICS_STACK absent; emit PORTAL_STACK absent
fi

# --- port conflicts (defaults: analytics UI 3000; portal 8083/8082) ----------
BUSY=""
for p in 3000 8080 5435 5555 8083 8082 8081; do
  if has ss && ss -ltn "( sport = :$p )" 2>/dev/null | grep -q ":$p"; then BUSY="$BUSY $p"
  elif has netstat && netstat -ltn 2>/dev/null | grep -q ":$p "; then BUSY="$BUSY $p"; fi
done
emit PORTS_BUSY "$(echo "$BUSY" | sed 's/^ //') "

# --- blockers (skill stops + reports if non-empty) ---------------------------
B=""
case "$(uname -m 2>/dev/null)" in x86_64|amd64) ;; *) B="$B arch-not-amd64";; esac
has docker || B="$B no-docker"
if has docker && ! docker info >/dev/null 2>&1; then B="$B docker-daemon-down"; fi
emit BLOCKERS "$(echo "$B" | sed 's/^ //')"

echo "=== END DISCOVERY ==="
