#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PG_VERSION="${PG_VERSION:-18.1}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-v0.8.1}"
BUNDLE_VERSION="${BUNDLE_VERSION:-$PG_VERSION}"

PLATFORM_ID="darwin-arm64v8"
TXZ_NAME="postgres-darwin-arm_64.txz"
JAR_NAME="embedded-postgres-binaries-${PLATFORM_ID}-${BUNDLE_VERSION}.jar"

WORK="$ROOT/build"
SRC="$WORK/src"
PREFIX="$WORK/prefix"
DIST="$ROOT/dist"

mkdir -p "$SRC" "$PREFIX" "$DIST" "$WORK/tmp"
rm -rf "$PREFIX"/*

echo "PG_VERSION=$PG_VERSION"
echo "PGVECTOR_VERSION=$PGVECTOR_VERSION"
echo "BUNDLE_VERSION=$BUNDLE_VERSION"

# Postgres 18 changed server APIs used by pgvector. Enforce a compatible pgvector tag.
if [[ "$PG_VERSION" == 18.* ]] && [[ "$PGVECTOR_VERSION" == "v0.8.0" || "$PGVECTOR_VERSION" == "0.8.0" ]]; then
  echo "pgvector $PGVECTOR_VERSION is not compatible with Postgres $PG_VERSION; use v0.8.1+"
  exit 1
fi

echo "Building Postgres ${PG_VERSION} + pgvector ${PGVECTOR_VERSION} for ${PLATFORM_ID}"

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

"$ROOT/scripts/build_postgres.sh" "$PG_VERSION" "$SRC" "$PREFIX"
"$ROOT/scripts/build_pgvector.sh" "$PGVECTOR_VERSION" "$SRC" "$PREFIX"
"$ROOT/scripts/test_install.sh" "$PREFIX"
"$ROOT/scripts/package.sh" "$PREFIX" "$DIST/$TXZ_NAME" "$DIST/$JAR_NAME"

echo "Done:"
echo "  - $DIST/$TXZ_NAME"
echo "  - $DIST/$JAR_NAME"
