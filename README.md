# embedded-postgres (Postgres + pgvector)

Builds a relocatable Postgres distribution with `pgvector` pre-installed, intended for "embedded" local dev setups (no Docker required for macOS builds).

This project mirrors the packaging style used by `io.zonky.test:embedded-postgres-binaries-*`:
- a `postgres-<platform>-<arch>.txz` containing `bin/`, `lib/`, `share/` at the archive root
- an optional `.jar` wrapper (a zip) that contains the `.txz` plus `META-INF/MANIFEST.MF`

## Supported Platforms

| Platform | Artifact names |
|----------|---------------|
| darwin arm64 | `postgres-darwin-arm_64.txz` / `embedded-postgres-binaries-darwin-arm64v8-<ver>.jar` |
| darwin amd64 | `postgres-darwin-x86_64.txz` / `embedded-postgres-binaries-darwin-amd64-<ver>.jar` |
| linux amd64 | `postgres-linux-x86_64.txz` / `embedded-postgres-binaries-linux-amd64-<ver>.jar` |

## Versions

Defaults (can be overridden via env vars):
- `PG_VERSION` (default: `18.1`)
- `PGVECTOR_VERSION` (default: `v0.8.1`)
- `BUNDLE_VERSION` (default: `${PG_VERSION}`)

## Local Build

### macOS (auto-detects arm64 or amd64)

Requires Xcode Command Line Tools.

```sh
./scripts/build.sh
```

Or use the backward-compatible wrapper for arm64:

```sh
./scripts/build_darwin_arm64.sh
```

### Linux (native)

Requires: build-essential, curl, git, pkg-config, patchelf, zip, zlib1g-dev, xz-utils, bzip2.

```sh
./scripts/build.sh
```

### Linux via Docker (from any host)

```sh
docker build -t lpg-builder .
docker run --rm -v "$PWD/dist:/out" lpg-builder
```

Artifacts land in `dist/`.

Release process: see `RELEASING.md`.
