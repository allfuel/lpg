# embedded-postgres (Postgres + pgvector)

Builds a relocatable Postgres distribution with `pgvector` pre-installed, intended for "embedded" local dev setups (no Docker required for macOS builds).

Artifacts are published as `postgres-<platform>-<arch>.tar.gz` archives containing `bin/`, `lib/`, and `share/` at the archive root.

## Supported Platforms

| Platform | Artifact names |
|----------|---------------|
| darwin arm64 | `postgres-darwin-arm_64.tar.gz` |
| darwin amd64 | `postgres-darwin-x86_64.tar.gz` |
| linux arm64 | `postgres-linux-arm_64.tar.gz` |
| linux amd64 | `postgres-linux-x86_64.tar.gz` |
| windows amd64 | `postgres-windows-x86_64.tar.gz` |

## Versions

Defaults (can be overridden via env vars):
- `PG_VERSION` (default: `18.1`)
- `PGVECTOR_VERSION` (default: `v0.8.1`)

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

Requires: build-essential, curl, git, pkg-config, patchelf, zlib1g-dev, xz-utils, bzip2.

```sh
./scripts/build.sh
```

### Linux via Docker (from any host)

```sh
docker build -t lpg-builder .
docker run --rm -v "$PWD/dist:/out" lpg-builder
```

### Windows (Git Bash)

Requires:
- Git Bash
- Visual Studio Build Tools (MSVC + `nmake`)
- `unzip`, `curl`, `tar`

```sh
./scripts/build_windows.sh
```

Artifacts land in `dist/`.

Release process: see `RELEASING.md`.
