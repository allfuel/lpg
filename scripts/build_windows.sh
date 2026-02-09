#!/usr/bin/env bash
# Windows build script — runs in Git Bash on GitHub Actions Windows runners.
#
# Unlike Unix builds, Windows PostgreSQL is NOT compiled from source.
# PGROOT must point to an existing PostgreSQL installation (set by the CI
# workflow via ankane/setup-postgres or a manual install).
# We compile pgvector from source using MSVC, test it, then package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PG_VERSION="${PG_VERSION:-18.1}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-v0.8.1}"
BUNDLE_VERSION="${BUNDLE_VERSION:-$PG_VERSION}"

# PGROOT must be set by the caller (CI workflow sets it from setup-postgres)
if [ -z "${PGROOT:-}" ]; then
  # Try common install locations
  for candidate in \
    "/c/Program Files/PostgreSQL/${PG_VERSION%%.*}" \
    "/c/Program Files/PostgreSQL/${PG_VERSION}"; do
    if [ -d "$candidate/bin" ]; then
      PGROOT="$candidate"
      break
    fi
  done
fi

if [ -z "${PGROOT:-}" ] || [ ! -d "${PGROOT}/bin" ]; then
  echo "PGROOT not set or invalid. Install PostgreSQL first (e.g. ankane/setup-postgres)."
  exit 1
fi

PLATFORM_ID="windows-amd64"
TXZ_NAME="postgres-windows-x86_64.txz"
JAR_NAME="embedded-postgres-binaries-${PLATFORM_ID}-${BUNDLE_VERSION}.jar"

WORK="$ROOT/build"
SRC="$WORK/src"
DIST="$ROOT/dist"

mkdir -p "$SRC" "$DIST"

echo "PG_VERSION=$PG_VERSION"
echo "PGVECTOR_VERSION=$PGVECTOR_VERSION"
echo "BUNDLE_VERSION=$BUNDLE_VERSION"
echo "PGROOT=$PGROOT"

# Postgres 18 changed server APIs used by pgvector.
if [[ "$PG_VERSION" == 18.* ]] && [[ "$PGVECTOR_VERSION" == "v0.8.0" || "$PGVECTOR_VERSION" == "0.8.0" ]]; then
  echo "pgvector $PGVECTOR_VERSION is not compatible with Postgres $PG_VERSION; use v0.8.1+"
  exit 1
fi

echo "Building pgvector ${PGVECTOR_VERSION} against Postgres ${PG_VERSION} for ${PLATFORM_ID}"

# --- Step 1: Build pgvector with MSVC ---------------------------------------

cd "$SRC"
rm -rf pgvector
echo "Cloning pgvector ${PGVECTOR_VERSION}"
git clone --depth 1 --branch "$PGVECTOR_VERSION" https://github.com/pgvector/pgvector.git
cd pgvector

echo "pgvector HEAD: $(git rev-parse HEAD)"

# Find vcvars64.bat for MSVC environment
if [ -z "${VCVARS_PATH:-}" ]; then
  echo "Looking for vcvars64.bat..."
  VCVARS_PATH="$(find "/c/Program Files/Microsoft Visual Studio" -name vcvars64.bat 2>/dev/null | head -1 || true)"
  if [ -z "$VCVARS_PATH" ]; then
    VCVARS_PATH="$(find "/c/Program Files (x86)/Microsoft Visual Studio" -name vcvars64.bat 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$VCVARS_PATH" ]; then
    echo "Could not find vcvars64.bat — Visual Studio required"
    exit 1
  fi
fi

# Convert Git Bash paths to Windows paths for cmd.exe
VCVARS_WIN="$(cygpath -w "$VCVARS_PATH")"
PGROOT_WIN="$(cygpath -w "$PGROOT")"
PGVECTOR_SRC_WIN="$(cygpath -w "$SRC/pgvector")"

echo "Using vcvars64.bat: $VCVARS_WIN"
echo "PGROOT (Windows): $PGROOT_WIN"

cmd.exe //C "call \"${VCVARS_WIN}\" && cd /d \"${PGVECTOR_SRC_WIN}\" && set \"PGROOT=${PGROOT_WIN}\" && nmake /NOLOGO /F Makefile.win && nmake /NOLOGO /F Makefile.win install"

echo "pgvector built and installed into PGROOT"

# --- Step 2: Test pgvector loads --------------------------------------------

INITDB="$PGROOT/bin/initdb.exe"
PG_CTL="$PGROOT/bin/pg_ctl.exe"
PSQL="$PGROOT/bin/psql.exe"

if [ ! -f "$INITDB" ] || [ ! -f "$PG_CTL" ] || [ ! -f "$PSQL" ]; then
  echo "Expected initdb/pg_ctl/psql under $PGROOT/bin"
  exit 1
fi

TESTDIR="$(mktemp -d)"

DATA="$TESTDIR/pgdata"
LOG="$TESTDIR/postgres.log"

"$INITDB" -D "$DATA" --username=postgres --auth=trust --no-instructions >/dev/null
"$PG_CTL" -D "$DATA" -l "$LOG" -o "-p 54321 -h 127.0.0.1" start >/dev/null

set +e
"$PSQL" -h 127.0.0.1 -p 54321 -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1
STATUS=$?
set -e

"$PG_CTL" -D "$DATA" -m fast stop >/dev/null

rm -rf "$TESTDIR"

if [ "$STATUS" -ne 0 ]; then
  echo "Failed to CREATE EXTENSION vector"
  exit 1
fi

echo "OK: pgvector extension loads"

# --- Step 3: Package --------------------------------------------------------

TMP="$(mktemp -d)"

STAGE="$TMP/stage"
mkdir -p "$STAGE/bin" "$STAGE/lib" "$STAGE/share"

# Binaries
for bin in postgres.exe pg_ctl.exe initdb.exe pg_isready.exe; do
  if [ -f "$PGROOT/bin/$bin" ]; then
    cp "$PGROOT/bin/$bin" "$STAGE/bin/"
  fi
done

# All DLLs from bin/ (needed for relocatability on Windows)
cp "$PGROOT"/bin/*.dll "$STAGE/bin/" 2>/dev/null || true

# Libraries (DLLs + .lib files + pgvector)
cp "$PGROOT"/lib/*.dll "$STAGE/lib/" 2>/dev/null || true
cp "$PGROOT"/lib/*.lib "$STAGE/lib/" 2>/dev/null || true

# Share (extension SQL files, timezone data, etc.)
cp -r "$PGROOT/share"/* "$STAGE/share/" 2>/dev/null || true

TXZ_OUT="$DIST/$TXZ_NAME"
JAR_OUT="$DIST/$JAR_NAME"

echo "Packaging txz: $TXZ_OUT"
tar -cJf "$TXZ_OUT" -C "$STAGE" bin lib share

echo "Packaging jar: $JAR_OUT"
mkdir -p "$TMP/jar/META-INF"
printf "Manifest-Version: 1.0\n" > "$TMP/jar/META-INF/MANIFEST.MF"
cp "$TXZ_OUT" "$TMP/jar/$(basename "$TXZ_OUT")"

ZIP="${ZIP:-}"
if [ -z "$ZIP" ]; then
  ZIP=zip
fi
(cd "$TMP/jar" && "$ZIP" -q -r "$JAR_OUT" .)

rm -rf "$TMP"

echo "Done:"
echo "  - $TXZ_OUT"
echo "  - $JAR_OUT"
