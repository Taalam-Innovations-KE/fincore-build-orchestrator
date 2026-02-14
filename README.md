# fincore-build-orchestrator

Build orchestration for distributed source repos:

- `Taalam-Innovations-KE/fineract`
- `Taalam-Innovations-KE/taalam-fincore-reporting-plugin`

The workflow in this repo builds Fineract from source, builds the reporting plugin from source, embeds plugin jars and Pentaho report templates into a final Docker image, and optionally pushes the image to GHCR.

## Workflow in this repo

- `.github/workflows/build-fineract-with-reporting-plugin.yml`

### Trigger modes

1. Manual trigger (`workflow_dispatch`) from this repo’s Actions tab.
2. Scheduled trigger (`schedule`) every 30 minutes from this repo.

### Matrix behavior

The workflow builds two image variants in parallel:

- `Postgresql` report templates
- `MariaDB` report templates

## Required secrets

In `Taalam-Innovations-KE/fincore-build-orchestrator`:

- `CROSS_REPO_TOKEN` (recommended): PAT/fine-grained token with read access to both source repos.
- `GHCR_TOKEN` (optional): token with `packages:write` if `GITHUB_TOKEN` is not enough for your org package policy.

## Manual build run

1. Open **Actions** in this repo.
2. Select **Build Fineract With Reporting Plugin**.
3. Click **Run workflow**.
4. Provide:
   - `fineract_ref` (for example `develop`)
   - `plugin_ref` (for example `develop`)
   - `image_repository` (for example `ghcr.io/taalam-innovations-ke/fineract-reports`)
   - `push_image` (`true` or `false`)
   - `force_rebuild` (`true` or `false`)

## Auto rebuild from this repo only

No workflow is required in the plugin repository.

The orchestrator workflow polls source refs on its schedule and computes a deterministic image tag:

`<fineract_sha>-<plugin_sha>-<db_variant>`

If `push_image=true` and that tag already exists in the registry, the run skips build/push.  
If you need a rebuild of an existing tag, run manually with `force_rebuild=true`.

## Runtime embedding layout

The image is built with `docker/fineract-with-reporting-plugin.Dockerfile` and embeds:

- plugin jars -> `/app/plugins`
- report templates -> `/app/pentahoReports`
- report path env var -> `FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports`
