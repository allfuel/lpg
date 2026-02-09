# Releasing `embedded-postgres`

This repo builds a relocatable Postgres distribution with `pgvector` pre-installed and publishes artifacts to GitHub Releases.

## What Gets Published

Each release publishes artifacts for all supported platforms:

| Platform | TAR.GZ |
|----------|-----|
| darwin arm64 | `postgres-darwin-arm_64.tar.gz` |
| darwin amd64 | `postgres-darwin-x86_64.tar.gz` |
| linux arm64 | `postgres-linux-arm_64.tar.gz` |
| linux amd64 | `postgres-linux-x86_64.tar.gz` |
| windows amd64 | `postgres-windows-x86_64.tar.gz` |

Notes:
- The `.tar.gz` contains only runtime dirs at the archive root: `bin/`, `lib/`, `share/`.
- `bin/` is intentionally minimal: `postgres`, `pg_ctl`, `initdb`, `pg_isready`.

## Version Inputs

The build is controlled by env vars / workflow inputs:

- `PG_VERSION`: Postgres version to build (example: `18.1`)
- `PGVECTOR_VERSION`: pgvector git tag to build (example: `v0.8.1`)

## Tag Naming Convention

Recommended tag format:

- `v<postgres>-pgvector<pgvector>`

Example:

- `v18.1-pgvector0.8.1`

## Release Steps (CI)

1. Ensure `scripts/build.sh` defaults are correct for the versions you want.
2. Push a tag:
   - `git tag v18.1-pgvector0.8.1`
   - `git push origin v18.1-pgvector0.8.1`
3. Wait for GitHub Actions workflow `build-embedded-postgres` to finish. All 5 platforms build in parallel.
4. Open the GitHub Release created for that tag and confirm all 5 `.tar.gz` assets are attached.

The workflow file is `.github/workflows/release.yml`.

## Release Steps (workflow_dispatch)

If you want a one-off build without tagging:

1. Run the workflow manually (Actions tab).
2. Provide inputs:
   - `pg_version` (example `18.1`)
   - `pgvector_version` (example `v0.8.1`)
3. Download artifacts from the workflow run ("Artifacts" section). There will be one artifact per platform.

`workflow_dispatch` uploads artifacts, but only tag builds upload to GitHub Releases.

## Quick Validation

### macOS

After downloading `postgres-darwin-arm_64.tar.gz` (or `postgres-darwin-x86_64.tar.gz`):

1. Extract it:
   - `mkdir -p /tmp/epg && tar -xzf postgres-darwin-arm_64.tar.gz -C /tmp/epg`
2. Confirm `pg_isready` and `initdb` are relocatable (libpq uses `@loader_path`):
   - `otool -L /tmp/epg/bin/initdb | head`
   - `otool -L /tmp/epg/bin/pg_isready | head`
3. Start a test cluster and load pgvector:
   - `/tmp/epg/bin/initdb -D /tmp/epgdata --username=postgres --auth=trust --no-instructions`
   - `/tmp/epg/bin/pg_ctl -D /tmp/epgdata -l /tmp/epg.log -o "-p 54321 -h 127.0.0.1" start`
   - (Optional) if you also have a client installed: `psql -h 127.0.0.1 -p 54321 -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;"`
   - `/tmp/epg/bin/pg_ctl -D /tmp/epgdata -m fast stop`

### Linux

After downloading `postgres-linux-x86_64.tar.gz`:

1. Extract it:
   - `mkdir -p /tmp/epg && tar -xzf postgres-linux-x86_64.tar.gz -C /tmp/epg`
2. Confirm binaries have correct RPATH:
   - `readelf -d /tmp/epg/bin/initdb | grep RPATH`
   - Should show `$ORIGIN/../lib`
3. Start a test cluster as above.

If you want the bundle itself to ship `psql`, adjust `scripts/package.sh`.
