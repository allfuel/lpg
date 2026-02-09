#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PG_VERSION="${PG_VERSION:-18.1}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-v0.8.1}"

# --- Platform / arch detection (overridable via env) -------------------------

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux"  ;;
    *)      echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    x86_64)        echo "amd64" ;;
    *)             echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
  esac
}

PLATFORM="${PLATFORM:-$(detect_platform)}"
ARCH="${ARCH:-$(detect_arch)}"

# Artifact naming conventions
case "$ARCH" in
  arm64) ARCH_SUFFIX="arm_64"  ;;
  amd64) ARCH_SUFFIX="x86_64"  ;;
  *)     echo "Unknown ARCH: $ARCH" >&2; exit 1     ;;
esac

ARCHIVE_NAME="postgres-${PLATFORM}-${ARCH_SUFFIX}.tar.gz"

# --- Workspace ---------------------------------------------------------------

WORK="$ROOT/build"
SRC="$WORK/src"
PREFIX="$WORK/prefix"
DIST="$ROOT/dist"

mkdir -p "$SRC" "$PREFIX" "$DIST" "$WORK/tmp"
rm -rf "$PREFIX"/*

echo "PG_VERSION=$PG_VERSION"
echo "PGVECTOR_VERSION=$PGVECTOR_VERSION"

# Postgres 18 changed server APIs used by pgvector. Enforce a compatible pgvector tag.
if [[ "$PG_VERSION" == 18.* ]] && [[ "$PGVECTOR_VERSION" == "v0.8.0" || "$PGVECTOR_VERSION" == "0.8.0" ]]; then
  echo "pgvector $PGVECTOR_VERSION is not compatible with Postgres $PG_VERSION; use v0.8.1+"
  exit 1
fi

echo "Building Postgres ${PG_VERSION} + pgvector ${PGVECTOR_VERSION} for ${PLATFORM}-${ARCH}"

# macOS-only: set deployment target
if [ "$PLATFORM" = "darwin" ]; then
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
fi

export PLATFORM

"$ROOT/scripts/build_postgres.sh" "$PG_VERSION" "$SRC" "$PREFIX"
"$ROOT/scripts/build_pgvector.sh" "$PGVECTOR_VERSION" "$SRC" "$PREFIX"
"$ROOT/scripts/test_install.sh" "$PREFIX"
"$ROOT/scripts/package.sh" "$PREFIX" "$DIST/$ARCHIVE_NAME"

echo "Done:"
echo "  - $DIST/$ARCHIVE_NAME"
