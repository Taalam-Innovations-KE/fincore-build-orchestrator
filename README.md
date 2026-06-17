# fincore-build-orchestrator

Deploys and orchestrates the full **FinCore** platform (Apache Fineract + tenancy
control plane + Keycloak OAuth2) via Docker Compose, in two flavors:

- **local** — no domains, no TLS, ports published to `localhost`
- **prod** — Traefik + Let's Encrypt on `patocapital.com`

It also contains the GitHub Actions workflow that builds the Fineract image with the
embedded Pentaho reporting plugin (see [Build workflow](#build-workflow) below).

## Architecture

```
                 Internet  (prod only)
              ┌─────────────┐  Traefik :80→:443  (TLS, Let's Encrypt)
              │   traefik   │
   ┌──────────┼─────────────┼────────────┐
   │ auth.*   │ tenants.*   │ apps.*      │
   ▼          ▼             ▼
 keycloak  tenancy-portal  fineract-ui        (all on the `fincore` network)
 (:8080)     (:3000)         (:3000)
                │               │
                ▼ proxy         ▼ proxy
        tenancy-service     Fineract API
            (:8080)           (:8443)
                └───────┬────────┘
                        ▼
                 Postgres (fincore-pg-db, alias fineractdb)
   DBs: keycloak | fineract_tenants | fineract_default | fineract_tenant_management
```

The two backends (**Fineract API** and **tenancy-service**) are never published — the
Next.js apps proxy to them over the internal `fincore` network.

### Services & images

| Service          | Image                                          | Source repo                              |
|------------------|------------------------------------------------|------------------------------------------|
| postgres         | `postgres:18.1-alpine`                         | —                                        |
| keycloak         | `taalam/fineract-keycloak-sso` (branded theme) | `pato-keycloakify-sso`                   |
| fineract         | `taalamke/taalam-fineract`                     | `fineract` (+ reporting plugin)          |
| fineract-ui      | `taalamke/taalam-fincore-web`                  | `fineract-ui`                            |
| tenancy-service  | `taalamke/taalam-tenant-management-service`    | `fineract-tenancy-management-service`    |
| tenancy-portal   | `taalamke/taalam-tenants-portal`               | `tenancy-management-portal`              |
| traefik          | `traefik:v3.1.7` (prod only)                   | —                                        |

## Quick start (local)

Prereqs: Docker + Docker Compose, and a one-time hosts entry so the OIDC issuer is
identical from your browser and from the containers:

```bash
echo "127.0.0.1   keycloak" | sudo tee -a /etc/hosts
```

Then use the `./fincore` helper (it creates `.env` files, validates them, creates the
network, and starts the stack):

```bash
./fincore init         # create any missing .env files from the templates
./fincore up local     # validate + bring everything up
```

`up` runs `check` first: for **local** unset/placeholder secrets are warnings (the
stack still starts with safe dev defaults); for **prod** they are hard errors. Run
`./fincore check local` any time to validate without starting. `make up-local` /
`make up-prod` are thin wrappers around the same script.

Endpoints:

- Keycloak:        http://keycloak:8080  (admin: `admin` / `admin123`)
- Banking UI:      http://localhost:3000
- Tenancy portal:  http://localhost:3001  (login: `platform-admin` / `ChangeMe123!`)
- Fineract API:    https://localhost:8443/fineract-provider/ (self-signed)
- Tenancy API:     http://localhost:8081
- Postgres:        localhost:5432

First-run flow: the `platform` realm is imported automatically. Log into the **tenancy
portal** and create a tenant — the tenancy-service provisions its database and a
per-tenant Keycloak realm. The **banking UI** then works for that tenant.

`make down` to stop.

## Production deployment

1. Point DNS A records at the server: `auth`, `tenants`, `apps` `.patocapital.com`.
2. Create real env files from the templates and set strong secrets (see
   [Secrets](#secrets)).
3. Set `traefik/.env` `LE_EMAIL` to a valid address for Let's Encrypt.
4. Validate and bring it up:

```bash
./fincore check prod   # fails fast if any required secret is still a placeholder
./fincore up prod
```

Traefik obtains certificates automatically. Only `auth/tenants/apps.patocapital.com`
are reachable publicly; the backends stay internal.

## Realm & OAuth2 model

- **`platform` realm** (control plane) — clients `tenants-portal` (the portal) and
  `fineract-tenant-management` (resource-server audience). Bootstrapped from
  `keycloak/import/platform-realm.json`.
- **per-tenant realms** — one realm per tenant for banking, each with a `fincore-web`
  client. Created automatically by **Fineract's Keycloak module** during tenant
  runtime-refresh (only when external OAuth2 is enabled — see below). The banking UI
  reads the tenant from the `/realms/{tenant}` issuer.

### Current default: basic auth

Fineract authenticates with **basic auth** (the banking-UI BFF uses a service account),
so the stack works out of the box. In this mode Fineract's Keycloak module is **off**,
so per-tenant realms are **not** auto-created.

Provisioning a tenant still works and is verified end-to-end: it creates the tenant DB,
migrates the full Fineract schema, and registers the tenant via the JWT-secured
`tenant-runtime` endpoint.

### Going fully Keycloak-on-Fineract (unlocks per-tenant realm auto-provisioning)

Fineract permits exactly **one** auth scheme, so this is an either/or with basic auth.
To switch:

1. In `fineract/.env`: set `FINERACT_SECURITY_OAUTH2_EXTERNAL_ENABLED=true`,
   `FINERACT_SECURITY_BASICAUTH_ENABLED=false`, `FINERACT_SECURITY_OAUTH_ENABLED=false`.
   (The `FINERACT_SECURITY_OAUTH2_EXTERNAL_PROVISIONING_*` vars are already set, incl. the
   `fineract-provisioner` admin client + `fincore-web` UI client.)
2. Create the **`fineract-provisioner`** client in Keycloak's **master** realm
   (confidential, service account, `admin` realm role) — it lets Fineract create
   per-tenant realms. (Not in the platform-realm import because it's a master-realm client.)
3. Update **fineract-ui** so the BFF forwards the user's Keycloak **access token** to
   Fineract instead of the basic-auth service account, and set `AUTH_LOGIN_MODE=keycloak`.
4. Recreate Fineract + banking UI. New tenants now get a `<tenant>` realm + `fincore-web`
   client created automatically on provisioning.

> Do **not** enable external OAuth2 while basic auth is still on — Fineract refuses to
> start ("Too many authentication schemes selected").

## Secrets

Real `.env` files are git-ignored; only `*.env.example` templates are committed.
Before going to prod, set strong values for at least:

- `postgres/.env`: all DB passwords
- `keycloak/.env`: `KC_BOOTSTRAP_ADMIN_PASSWORD`, DB password
- `fineract-ui/.env` & `tenancy-portal/.env`: `AUTH_SECRET` (`openssl rand -base64 32`),
  `AUTH_KEYCLOAK_SECRET`
- `keycloak/import/platform-realm.json`: the `tenants-portal` client `secret` **must
  match** `tenancy-portal/.env` `AUTH_KEYCLOAK_SECRET`

> The previously committed `AUTH_SECRET` and Keycloak client secret remain in git
> history — rotate them.

## Build workflow

Builds Fineract from source, embeds the reporting plugin artifacts (prebuilt ZIP by
default, source build optional) and Pentaho report templates, and optionally pushes the
image to Docker Hub or GHCR.

Workflow: `.github/workflows/build-fineract-with-reporting-plugin.yml` (manual
`workflow_dispatch`). Primary image tag is deterministic: `<fineract_sha>-<plugin_sha>`;
`push_image=true` also pushes `latest`.

### Required secrets (in this repo)

- `CROSS_REPO_TOKEN` — read access to the source repos
- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` — Docker Hub pushes
- `GHCR_TOKEN` — GHCR pushes (`packages:write`)

### Manual run

Actions → **Build Fineract With Reporting Plugin** → **Run workflow**, providing
`fineract_ref`, `plugin_source` (+ `plugin_zip_url`/`plugin_zip_sha256` for prebuilt),
`reports_datasource_host/user/password`, `image_repository`, `push_image`. Use
datasource values that match your runtime tenant DB credentials, or Pentaho parameter
metadata/cache prep can fail before report execution.

### Runtime embedding layout

Built with `docker/fineract-with-reporting-plugin.Dockerfile`, the image embeds plugin
jars (`/app/plugins`), Postgresql/MariaDB report templates
(`/app/pentahoReports/{Postgresql,MariaDB}`), build-time PRPT datasource rewrites, and
PDF fonts. `fineract/.env` selects the template set at runtime via
`FINERACT_REPORTS_DB_TYPE` (`postgresql` | `mariadb`).

The Fineract container runs as root by default (`FINERACT_CONTAINER_USER=0:0`) to avoid
UID/GID drift on the mounted content path; override in `fineract/.env`. Imports/uploads
write to the bind mount `./fineract/data/fineract-content` →
`/opt/fineract-content` (`FINERACT_CONTENT_FILESYSTEM_*`).
