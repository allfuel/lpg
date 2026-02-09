#!/usr/bin/env bash
set -euo pipefail

PG_VERSION="${1:?PG_VERSION required}"
SRC_DIR="${2:?SRC_DIR required}"
PREFIX="${3:?PREFIX required}"

TARBALL="postgresql-${PG_VERSION}.tar.bz2"
URL="https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${TARBALL}"

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

if [ ! -f "$TARBALL" ]; then
  echo "Downloading Postgres source: $URL"
  curl -fL -o "$TARBALL" "$URL"
fi

rm -rf "postgresql-${PG_VERSION}"
tar -xjf "$TARBALL"

cd "postgresql-${PG_VERSION}"

JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 4)"

./configure \
  --prefix="$PREFIX" \
  --without-icu \
  --without-llvm \
  --without-readline

make -j"$JOBS"
make install

