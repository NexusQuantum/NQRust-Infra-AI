# Reference — NQRust Identity Portal

> **This is the OFFLINE FALLBACK.** The primary source of truth is the live docs at
> **https://docs-identity.nexusquantum.id** (locale-prefixed `/en/…`; e.g.
> `/en/guides/installation/phase-1-identity`, `…/phase-2-portal`, `…/add-new-client`). Fetch those
> first (web fetch); use this file when offline/airgapped or for the exact compose/env facts
> below. See SKILL.md → "Documentation sources".

Identity Portal stack: an OIDC provider (Identity, Keycloak-based) + a Next.js Portal
behind Traefik with HTTPS, gated by a license. Deployed via the `nqrust-portal` TUI
installer. Source: github.com/NexusQuantum/installer-NQRust-Portal

## Services (docker-compose) — fixed container names
| Container | Image | Exposed port | Role |
|---|---|---|---|
| `nqrust-traefik` | traefik:v3.4 | **8083**→443 (portal), **8082**→8444 (identity), 8081 (dashboard) | Reverse proxy + self-signed HTTPS |
| `nqrust-identity` | ghcr.io/nexusquantum/nqrust-identity | via Traefik (internal 8080; health on 9000) | OIDC / OAuth2 provider |
| `nqrust-identity-db` | postgres:16-alpine | internal only | Identity + license data |
| `nqrust-identity-portal` | ghcr.io/nexusquantum/nqrust-identity-portal | via Traefik | The Portal (Next.js) with license gate |

`PORTAL_PORT` (default 8083) and `IDENTITY_PORT` (default 8082) are the host-facing HTTPS ports.

## Install — TWO PHASES (this is the key difference from Analytics)
After the binary is on PATH (`.deb` one-liner, source, or airgapped):
```
nqrust-portal
```
**Phase 1 — Initial setup.** Installer prompts for:
| Field | Default |
|---|---|
| Hostname / IP (used in HTTPS URLs) | — (ask user) |
| Portal Port | 8083 |
| Identity Port | 8082 |
| Admin Password (Identity bootstrap) | — (ask user) |
| Realm Name | master |
| Client ID | nqrust-portal |
| Client Secret | **leave blank in Phase 1** |

After Phase 1: Portal at `https://<host>:8083`, Identity admin at `https://<host>:8082/admin`.
A **license key** is required to use the portal.

**Phase 2 — Apply Identity client config.** AFTER configuring the OAuth client in the
Identity admin console:
1. Open `https://<host>:8082/admin`, log in with the admin password from Phase 1.
2. Create/configure the realm + client (`nqrust-portal`).
3. **Valid redirect URIs** → the portal's OAuth callback (typically `…/api/auth/callback/…` on `https://<host>:8083`).
4. Set Root / Home / Web origins / Admin URLs to `https://<host>:8083`.
5. Copy the **client secret**.
6. Re-run `nqrust-portal`, choose **Phase 2**, paste the client secret + realm to apply.

> Phase 2 needs human action in the Identity admin UI (creating the client). The skill
> drives the installer for both phases but must PAUSE between them and tell the user to do
> the admin-console step, then resume Phase 2 once they have the client secret.

## Post-install
1. **Activate license** — visit `https://<host>:8083/license-activation`, enter the license key.
2. **Login** via Identity (OIDC).
3. **Access portal** — `https://<host>:8083/dashboard`.
> Browser shows a cert warning — Traefik uses a **self-signed cert**. Expected; click Advanced → Proceed.

## Key `.env` variables (from env_template)
- `PORTAL_PORT`, `IDENTITY_PORT`
- `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET` (filled in Phase 2)
- `KEYCLOAK_ISSUER=http://identity:8080/realms/<realm>`,
  `KEYCLOAK_EXTERNAL_HOST=https://<host>:<IDENTITY_PORT>`
- `KEYCLOAK_ADMIN=admin`, `KEYCLOAK_ADMIN_PASSWORD` (Phase 1 admin password)
- `KEYCLOAK_DB_NAME/USER/PASSWORD=identity`
- `DATABASE_URL=postgresql://identity:identity@identity-db:5432/nqrust_portal`
- `NEXTAUTH_URL=https://<host>:<PORTAL_PORT>`, `NEXTAUTH_SECRET`
- `NEXT_PUBLIC_LICENSE_*`, `LICENSE_PUBLIC_KEY`, `NEXT_PUBLIC_LICENSE_SERVER_URL=https://billing.nexusquantum.id`

## Day-2 commands (run in the install dir)
- `docker compose ps` · `docker compose logs -f nqrust-identity` / `… portal`
- Identity health (internal): `docker exec nqrust-identity curl -fsS http://localhost:9000/health/ready`
- Restart: `docker compose restart portal` / `docker compose restart identity`
- Stop / start: `docker compose down` / `docker compose up -d`

## Install methods recap (decide at runtime — see SKILL.md)
- **.deb one-liner (preferred, online):**
  `curl -fsSL https://raw.githubusercontent.com/NexusQuantum/installer-NQRust-Portal/main/scripts/install/install.sh | bash`
  then `nqrust-portal`
- **From source:** `git clone … && docker login ghcr.io && cargo run`
- **Airgapped:** build `nqrust-portal-airgapped-installer-<ver>-amd64` on an online box
  (`./scripts/airgapped/build-single-binary.sh`, ~3–4 GB), transfer + verify `.sha256`,
  `chmod +x`, run it. CI for airgapped images needs the `GHCR_TOKEN` repo secret.

## Relationship to Analytics SSO
The Portal/Identity provider is the OIDC source that Analytics can use for SSO: in the
Analytics `.env`, set `KEYCLOAK_OAUTH_ENABLED=true` and point `KEYCLOAK_URL`/`KEYCLOAK_REALM`/
`KEYCLOAK_CLIENT_ID`/`KEYCLOAK_CLIENT_SECRET` at this Identity. So a full "suite" install is
often: Portal/Identity first → create an Analytics OAuth client → then wire Analytics to it.
