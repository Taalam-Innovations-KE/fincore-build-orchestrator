# fincore-build-orchestrator

Build orchestration for distributed source repos:

- `Taalam-Innovations-KE/fineract`
- `Taalam-Innovations-KE/taalam-fincore-reporting-plugin`

The workflow in this repo builds Fineract from source, builds the reporting plugin from source, embeds plugin jars and Pentaho report templates into a final Docker image, and optionally pushes the image to Docker Hub (or GHCR).

## Workflow in this repo

- `.github/workflows/build-fineract-with-reporting-plugin.yml`

### Trigger mode

1. Manual trigger (`workflow_dispatch`) from this repo’s Actions tab.

### Image and tag behavior

The workflow builds one image per run.  
The image tag is deterministic:

`<fineract_sha>-<plugin_sha>`

## Required secrets

In `Taalam-Innovations-KE/fincore-build-orchestrator`:

- `CROSS_REPO_TOKEN` (recommended): PAT/fine-grained token with read access to both source repos.
- `DOCKERHUB_USERNAME` (required for Docker Hub pushes): your Docker Hub username.
- `DOCKERHUB_TOKEN` (required for Docker Hub pushes): Docker Hub access token.
- `GHCR_TOKEN` (required for GHCR pushes): token with `packages:write`.

## Manual build run

1. Open **Actions** in this repo.
2. Select **Build Fineract With Reporting Plugin**.
3. Click **Run workflow**.
4. Provide:
   - `fineract_ref` (for example `develop`)
   - `plugin_ref` (for example `develop`)
   - `image_repository` (for example `taalamke/taalam-fineract`)
   - `push_image` (`true` or `false`)
   - `force_rebuild` (`true` or `false`)

## Rebuild behavior

The orchestrator computes a deterministic image tag:

`<fineract_sha>-<plugin_sha>`

If `push_image=true` and that tag already exists in the registry, the run skips build/push.  
If you need a rebuild of an existing tag, run manually with `force_rebuild=true`.

## Runtime embedding layout

The image is built with `docker/fineract-with-reporting-plugin.Dockerfile` and embeds:

- plugin jars -> `/app/plugins`
- Postgresql report templates -> `/app/pentahoReports/Postgresql`
- MariaDB report templates -> `/app/pentahoReports/MariaDB`
- default report path env var -> `FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports/Postgresql`

### Runtime DB selector via env file

`fineract/compose.yaml` now maps one selector variable into the plugin report path:

- `FINERACT_REPORTS_DB_TYPE=postgresql` -> `/app/pentahoReports/postgresql`
- `FINERACT_REPORTS_DB_TYPE=mariadb` -> `/app/pentahoReports/mariadb`

Set this in your env file (for example `fineract/.env`) and start compose normally.  
You can also override the image in the same env file using `FINERACT_IMAGE=<repo:tag>`.
