# nqrust-suite · Troubleshooting RUNBOOK

Symptom → cause → fix for NexusQuantum Analytics and NQRust Identity Portal.
**Always confirm the symptom from live output first** (`scripts/status.sh`,
`scripts/logs.sh <container>`), quote the real error, then apply the matching fix.
Never report a fix as "done" without re-checking state (see SKILL.md golden rules).

---

## Shared (both products)

### `unauthorized` / `denied` when pulling images from ghcr.io
**Cause:** Docker not logged in to GHCR, or PAT lacks `read:packages`.
**Fix:** `docker login ghcr.io` with a GitHub PAT (scope `read:packages`) as the password.
The skill sources the PAT from `$GHCR_PAT` / a workspace token file — see SKILL.md "Credentials".
Verify: re-run the pull or `docker compose pull`.

### Port conflict — a service won't start, "address already in use"
**Cause:** another process holds the port (Analytics UI 3000 / engine 8080 / pg 5435 / AI 5555;
Portal 8083 / 8082 / 8081).
**Fix:** find it (`ss -ltnp | grep :<port>`), then either free it or change the port in `.env`
(`ANALYTICS_UI_PORT`, `POSTGRES_PORT`, … / `PORTAL_PORT`, `IDENTITY_PORT`) and `docker compose up -d`.

### Build errors (source/airgapped build)
`cargo clean && cargo build --release`. For airgapped, confirm `docker login ghcr.io` succeeded
before `./scripts/airgapped/build-single-binary.sh` (it bundles pulled images).

### Daemon down / `Cannot connect to the Docker daemon`
Start Docker (`sudo systemctl start docker`) and ensure your user is in the `docker` group (or use sudo).
`discover.sh` reports this as `BLOCKERS=docker-daemon-down`.

---

## Analytics

### `password authentication failed for user "analytics"` / `role "analytics" does not exist`
**Cause:** Postgres only runs `/docker-entrypoint-initdb.d/` scripts when the data volume is
**empty** (first run). A pre-existing `analytics_northwind_data` volume from before the analytics
user existed means the init never created it.
**Fix (pick one):**
1. **Preferred** — ensure the `analytics-db-init` service runs (it's idempotent; needs
   `scripts/ensure-analytics-db.sh`). `docker compose up -d` after pulling the latest bundle.
2. **Manual one-time:**
   ```
   docker exec -i analytics-northwind-db-1 psql -U demo -d postgres -c \
     "CREATE USER analytics WITH PASSWORD 'analytics123'; CREATE DATABASE analytics OWNER analytics; GRANT ALL PRIVILEGES ON DATABASE analytics TO analytics;"
   docker compose restart analytics-ui
   ```
   (Container name may differ — confirm with `docker ps`.)
3. **Fresh start (DATA LOSS — confirm with user):**
   `docker compose down && docker volume rm analytics_northwind_data && docker compose up -d`

### `.env file detected but doesn't exist`
Old installer bug — a stray `.env` in a **parent** directory was detected. Update the installer,
or ensure no `.env` exists above the project dir.

### Documents stuck at "indexing" / Document RAG callbacks fail silently
**Cause:** `CALLBACK_BASE_URL` must be reachable from inside the AI service container — it must be
the docker service name, not the host IP. Default `http://analytics-ui:3000`.
**Fix:** confirm `CALLBACK_BASE_URL=http://analytics-ui:3000` in `.env`, restart `analytics-service`.

### Qdrant 409 Conflict / AI service workers crash-looping
**Cause:** `SHOULD_FORCE_DEPLOY=1` makes every worker rebuild collections on startup → race.
**Fix:** set `SHOULD_FORCE_DEPLOY=0` (or remove it) in `.env`, restart `analytics-service`.

### UI loads but queries fail / engine unreachable
Check `analytics-engine` and `ibis-server` are up (`status.sh analytics`); inspect
`logs.sh analytics-engine`. Confirm `OPENAI_API_KEY` (or chosen provider key) is valid in `.env`.

---

## Portal / Identity

### Browser certificate warning
**Expected** — Traefik uses a self-signed cert. Advanced → Proceed. Not a fault.

### Portal stuck on license activation after clearing cookies
**Cause:** negative-cache of the license lookup. If the license IS in the DB it's harmless.
**Fix:** wait a moment and refresh, or `docker compose restart portal`.

### Phase 2 / login loop — OAuth redirect mismatch
**Cause:** the Identity client's **Valid redirect URIs** / Web origins don't match the portal URL,
or the client secret in `.env` is stale.
**Fix:** in the Identity admin console set redirect URIs + Root/Home/Web-origin/Admin URLs to
`https://<host>:8083` (callback under `/api/auth/callback/…`), copy the client secret, re-run
`nqrust-portal` → **Phase 2** to apply it. Confirm `KEYCLOAK_CLIENT_SECRET` updated in `.env`.

### Identity never becomes healthy
Check `logs.sh nqrust-identity`. Health is `http://localhost:9000/health/ready` **inside** the
container: `docker exec nqrust-identity curl -fsS http://localhost:9000/health/ready`. Common
causes: `nqrust-identity-db` not healthy yet (wait/retry), wrong `KEYCLOAK_DB_*` creds, or
`KC_HOSTNAME`/`KEYCLOAK_EXTERNAL_HOST` mismatch.

### Traefik returns 404 / bad gateway for portal or identity
Confirm `nqrust-traefik` is running and the `traefik/dynamic.yml` mounted. Check the entrypoints:
portal on 443 (host `PORTAL_PORT`), identity on 8444 (host `IDENTITY_PORT`). `logs.sh nqrust-traefik`.

---

## When you can't determine the cause
Gather and quote: `status.sh all`, `logs.sh <failing-container> 200`,
`docker compose ps`, and the exact error text. For symptoms not covered above, **fetch the live
docs** and cite the page — Analytics: https://docs.analytics.nexusquantum.id ; Identity/Portal:
https://docs-identity.nexusquantum.id (e.g. the `/en/guides/server/…` and
`/en/guides/securing-applications/…` sections). State plainly what's failing and the most likely
cause; do NOT fabricate a root cause or claim a fix worked without re-verifying.
