# Releasing `embedded-postgres`

This repo builds a relocatable Postgres distribution with `pgvector` pre-installed and publishes artifacts to GitHub Releases.

## What Gets Published

Each release publishes two assets:

1. `postgres-darwin-arm_64.txz`
2. `embedded-postgres-binaries-darwin-arm64v8-<bundle_version>.jar`

Notes:
- The `.jar` is just a zip wrapper containing `postgres-darwin-arm_64.txz` + `META-INF/MANIFEST.MF` (mirrors `embedded-postgres-binaries-*` layout).
- The `.txz` contains only runtime dirs at the archive root: `bin/`, `lib/`, `share/`.
- `bin/` is intentionally minimal: `postgres`, `pg_ctl`, `initdb`, `pg_isready`.

## Version Inputs

The build is controlled by env vars / workflow inputs:

- `PG_VERSION`: Postgres version to build (example: `18.1`)
- `PGVECTOR_VERSION`: pgvector git tag to build (example: `v0.8.1`)
- `BUNDLE_VERSION`: suffix used in the `.jar` filename (example: `18.1-pgvector0.8.1`)

In CI, if `BUNDLE_VERSION` is not set and the workflow is running on a tag, `BUNDLE_VERSION` defaults to the tag name without the leading `v`.

## Tag Naming Convention

Recommended tag format:

- `v<postgres>-pgvector<pgvector>`

Example:

- `v18.1-pgvector0.8.1`

This produces:

- `embedded-postgres-binaries-darwin-arm64v8-18.1-pgvector0.8.1.jar`

## Release Steps (CI)

1. Ensure `embedded-postgres/scripts/build_darwin_arm64.sh` defaults are correct for the versions you want.
2. Push a tag:
   - `git tag v18.1-pgvector0.8.1`
   - `git push origin v18.1-pgvector0.8.1`
3. Wait for GitHub Actions workflow `build-embedded-postgres` to finish.
4. Open the GitHub Release created for that tag and confirm both assets are attached.

The workflow file is `embedded-postgres/.github/workflows/release.yml`.

## Release Steps (workflow_dispatch)

If you want a one-off build without tagging:

1. Run the workflow manually (Actions tab).
2. Provide inputs:
   - `pg_version` (example `18.1`)
   - `pgvector_version` (example `v0.8.1`)
   - `bundle_version` (optional, otherwise defaults to `pg_version`)
3. Download artifacts from the workflow run ("Artifacts" section).

`workflow_dispatch` uploads artifacts, but only tag builds upload to GitHub Releases.

## Quick Validation

After downloading `postgres-darwin-arm_64.txz`:

1. Extract it:
   - `mkdir -p /tmp/epg && tar -xJf postgres-darwin-arm_64.txz -C /tmp/epg`
2. Confirm `pg_isready` and `initdb` are relocatable (libpq uses `@loader_path`):
   - `otool -L /tmp/epg/bin/initdb | head`
   - `otool -L /tmp/epg/bin/pg_isready | head`
3. Start a test cluster and load pgvector:
   - `/tmp/epg/bin/initdb -D /tmp/epgdata --username=postgres --auth=trust --no-instructions`
   - `/tmp/epg/bin/pg_ctl -D /tmp/epgdata -l /tmp/epg.log -o "-p 54321 -h 127.0.0.1" start`
   - (Optional) if you also have a client installed: `psql -h 127.0.0.1 -p 54321 -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;"`
   - `/tmp/epg/bin/pg_ctl -D /tmp/epgdata -m fast stop`

If you want the bundle itself to ship `psql`, adjust `embedded-postgres/scripts/package.sh`.

