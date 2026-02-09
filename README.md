# embedded-postgres (Postgres + pgvector)

Builds a relocatable Postgres distribution with `pgvector` pre-installed, intended for "embedded" local dev setups (no Docker).

This project is designed to mirror the packaging style used by `io.zonky.test:embedded-postgres-binaries-*`:
- a `postgres-<platform>.txz` containing `bin/`, `lib/`, `share/` at the archive root
- an optional `.jar` wrapper (a zip) that contains the `.txz` plus `META-INF/MANIFEST.MF`

## Outputs

For `darwin-arm64` the build produces:
- `dist/postgres-darwin-arm_64.txz`
- `dist/embedded-postgres-binaries-darwin-arm64v8-<bundle_version>.jar`

Release process: see `embedded-postgres/RELEASING.md`.

## Versions

Defaults (can be overridden via env vars):
- `PG_VERSION` (default: `18.1`)
- `PGVECTOR_VERSION` (default: `v0.8.1`)
- `BUNDLE_VERSION` (default: `${PG_VERSION}`)

## Local Build (macOS arm64)

Requires Xcode Command Line Tools.

```sh
cd embedded-postgres
PG_VERSION=18.1 PGVECTOR_VERSION=v0.8.1 ./scripts/build_darwin_arm64.sh
```

Artifacts land in `embedded-postgres/dist/`.
