#!/usr/bin/env bash
set -euo pipefail

PGVECTOR_VERSION="${1:?PGVECTOR_VERSION required (e.g. v0.8.1)}"
SRC_DIR="${2:?SRC_DIR required}"
PREFIX="${3:?PREFIX required}"

PG_CONFIG="$PREFIX/bin/pg_config"
if [ ! -x "$PG_CONFIG" ]; then
  echo "pg_config not found at $PG_CONFIG"
  exit 1
fi

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

rm -rf pgvector
echo "Cloning pgvector ${PGVECTOR_VERSION}"
git clone --depth 1 --branch "$PGVECTOR_VERSION" https://github.com/pgvector/pgvector.git

cd pgvector
echo "pgvector HEAD: $(git rev-parse HEAD)"
git describe --tags --always 2>/dev/null || true

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 4)"

make -j"$JOBS" PG_CONFIG="$PG_CONFIG"
make install PG_CONFIG="$PG_CONFIG"
