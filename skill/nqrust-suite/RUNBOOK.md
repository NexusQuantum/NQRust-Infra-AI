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

### Analytics install fails at the end: "Docker Compose up failed" / `analytics-northwind-db-1 is unhealthy` / UI never starts (port 3000 dead)
**Symptom:** the installer pulls images and starts most services, then fails with
`dependency northwind-db failed to start` / `container analytics-northwind-db-1 is unhealthy`.
`docker ps -a` shows `analytics-ui` (and `analytics-db-init`) stuck in `Created`, so
`http://<host>:3000` refuses connections.
**Root cause (seen on a fresh VM):** the DB init SQL files the compose mounts read-only into
postgres are mode **0600** (owned by the install user), e.g.
`./00-init-analytics-db.sql:/docker-entrypoint-initdb.d/00-init-analytics-db.sql:ro`. Postgres
runs as a DIFFERENT uid inside the container and gets `psql: error: …: Permission denied` reading
them, so DB init fails and dependents never come up. Check the postgres logs:
`docker logs analytics-northwind-db-1 2>&1 | grep -i denied`.
**Fix:** make the mounted init files world-readable, then recreate the DB volume so init re-runs
(postgres SKIPS init if the data dir already exists — fixing perms alone is not enough). In the
stack dir (where `docker-compose.yaml` lives, e.g. `/home/<user>`):
```
chmod 644 00-init-analytics-db.sql northwind.sql scripts/ensure-analytics-db.sh
sudo docker compose down
sudo docker volume ls | grep -i northwind          # find the DB volume name
sudo docker volume rm <project>_northwind_data     # delete it so init re-runs
sudo docker compose up -d
```
**Verify:** `docker ps | grep -E 'northwind|analytics-ui'` (both Up; northwind `healthy`) and
`curl -I http://localhost:3000` returns an HTTP status. Report the real result — don't claim the
UI is up without the curl.

### Airgapped install dies during "Extracting / Loading embedded Docker images" — DISK FULL
**Symptom:** the airgapped binary runs, gets to "Verifying payload integrity" → "Extracting
embedded Docker images", progresses partway (e.g. ~1.2 / 1.8 GiB), then the installer process
disappears / the tmux session dies, and `df -h /` shows the root disk at **100%** (a few hundred
MB free). No analytics containers come up.
**Root cause:** not enough free disk. The airgapped path needs the binary (~1.8 GB) + the extracted
image tar (~1.8 GB) + `docker load` layers (~4 GB) + stack volumes simultaneously — a 20 GB root
disk fills up. This is a CAPACITY problem, not a bug in the binary.
**Fix:**
- Prevent it: check `df -h /` BEFORE downloading; require ≥ 25 GB free for Analytics airgapped
  (≥ 12 GB for Portal). See SKILL.md "Step 2 → Disk preflight".
- Recover on a too-small disk: free space (`sudo docker system prune -af`, delete the downloaded
  `nqrust-*-airgapped-installer-*` binary after it has extracted, remove half-loaded images), then
  either grow the VM's root disk and retry, or move to a VM with a ≥ 40 GB disk, or use the ONLINE
  installer (lower peak local disk, streams images).
- Don't "retry on the same full disk" — it fails the same way. Fix capacity first.

---

## When you can't determine the cause
Gather and quote: `status.sh all`, `logs.sh <failing-container> 200`,
`docker compose ps`, and the exact error text. For symptoms not covered above, **fetch the live
docs** and cite the page — Analytics: https://docs.analytics.nexusquantum.id ; Identity/Portal:
https://docs-identity.nexusquantum.id (e.g. the `/en/guides/server/…` and
`/en/guides/securing-applications/…` sections). State plainly what's failing and the most likely
cause; do NOT fabricate a root cause or claim a fix worked without re-verifying.
