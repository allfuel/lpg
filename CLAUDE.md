# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Build/packaging system that creates relocatable PostgreSQL distributions with pgvector pre-installed. Supports macOS (ARM64, AMD64) and Linux (AMD64). Mirrors the `io.zonky.test:embedded-postgres-binaries-*` packaging format.

Outputs two artifacts per platform in `dist/`:
- `postgres-<platform>-<arch>.txz` — bin/, lib/, share/ at archive root
- `embedded-postgres-binaries-<platform>-<docker_arch>-<version>.jar` — zip wrapper containing the txz + MANIFEST.MF

Platform/arch naming follows zonkyio conventions:
| Platform | TXZ arch | Docker/JAR arch |
|----------|----------|-----------------|
| darwin arm64 | arm_64 | arm64v8 |
| darwin amd64 | x86_64 | amd64 |
| linux amd64 | x86_64 | amd64 |

## Build Commands

```sh
# Generic build (auto-detects platform/arch)
./scripts/build.sh

# Override platform/arch
PLATFORM=linux ARCH=amd64 ./scripts/build.sh

# Backward-compatible macOS ARM64 wrapper
./scripts/build_darwin_arm64.sh

# Linux build via Docker (from macOS or any Docker host)
docker build -t lpg-builder .
docker run --rm -v "$PWD/dist:/out" lpg-builder

# Individual steps (called by build.sh in sequence):
./scripts/build_postgres.sh     # Download & compile PostgreSQL
./scripts/build_pgvector.sh     # Compile pgvector against built Postgres
./scripts/test_install.sh       # Validate pgvector loads in a temp cluster (port 54321)
./scripts/package.sh            # Create txz/jar in dist/
```

Version defaults are set in `build.sh` and can be overridden via env vars: `PG_VERSION`, `PGVECTOR_VERSION`, `BUNDLE_VERSION`, `MACOSX_DEPLOYMENT_TARGET` (default 13.0, darwin only).

## Architecture

**Build pipeline** — shell scripts in `scripts/`, orchestrated by `build.sh`:

1. `build.sh` — generic orchestrator: detects platform/arch, normalizes naming, calls steps in sequence
2. `build_darwin_arm64.sh` — thin wrapper that sets `PLATFORM=darwin ARCH=arm64` and execs `build.sh`
3. `build_postgres.sh` — downloads source tarball, configures with `--without-icu --without-llvm --without-readline`, compiles to `build/prefix/`
4. `build_pgvector.sh` — clones pgvector from GitHub, builds against `build/prefix/bin/pg_config`
5. `test_install.sh` — spins up a temp Postgres cluster on port 54321, runs `CREATE EXTENSION vector`, tears down
6. `package.sh` — copies only 4 binaries (postgres, pg_ctl, initdb, pg_isready) plus full lib/ and share/, fixes library paths for relocatability, creates txz and jar
   - Darwin: rewrites dylib paths with `install_name_tool` (`@loader_path`)
   - Linux: sets RPATH with `patchelf` (`$ORIGIN`)

**Directory layout during build:**
- `build/src/` — downloaded sources
- `build/prefix/` — compiled installation (full)
- `build/tmp/` — temp packaging workspace
- `dist/` — final artifacts

All scripts use `set -euo pipefail`. Both `build/` and `dist/` are gitignored.

## Releasing

- **Tag-triggered**: push tag like `v18.1-pgvector0.8.1` → GitHub Actions builds on 3 platforms (darwin-arm64, darwin-amd64, linux-amd64) and uploads to GitHub Releases
- **Manual**: use `workflow_dispatch` from Actions tab (artifacts only, no release)
- CI config: `.github/workflows/release.yml`

## Key Constraints

- Postgres 18.x requires pgvector v0.8.1+ (enforced in `build.sh`)
- Binary relocatability is critical — `package.sh` rewrites library paths per platform
- Only 4 binaries are shipped (no psql, pg_dump, etc.) to minimize footprint
- Linux builds require `patchelf` for RPATH fixup
