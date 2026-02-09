#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?PREFIX required}"
TXZ_OUT="${2:?TXZ_OUT required}"
JAR_OUT="${3:?JAR_OUT required}"

TXZ_OUT_DIR="$(cd "$(dirname "$TXZ_OUT")" && pwd)"
JAR_OUT_DIR="$(cd "$(dirname "$JAR_OUT")" && pwd)"
mkdir -p "$TXZ_OUT_DIR" "$JAR_OUT_DIR"

TXZ_OUT="${TXZ_OUT_DIR}/$(basename "$TXZ_OUT")"
JAR_OUT="${JAR_OUT_DIR}/$(basename "$JAR_OUT")"

# Auto-detect platform if not set by build.sh
if [ -z "${PLATFORM:-}" ]; then
  case "$(uname -s)" in
    Darwin) PLATFORM="darwin" ;;
    Linux)  PLATFORM="linux"  ;;
    *)      echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STAGE="$TMP/stage"
mkdir -p "$STAGE/bin"

# Keep the runtime footprint similar to embedded-postgres-binaries: ship only
# the server + cluster management tools. (We still ship full lib/share so
# extensions like pgvector work.)
for bin in postgres pg_ctl initdb pg_isready; do
  if [ ! -x "$PREFIX/bin/$bin" ]; then
    echo "Missing expected binary: $PREFIX/bin/$bin"
    exit 1
  fi
  cp -a "$PREFIX/bin/$bin" "$STAGE/bin/"
done

cp -a "$PREFIX/lib" "$STAGE/"
cp -a "$PREFIX/share" "$STAGE/"

# --- Darwin: rewrite dylib paths to @loader_path for relocatability ----------

fix_darwin() {
  local bin="$1"
  local want='@loader_path/../lib/libpq.5.dylib'

  if ! command -v /usr/bin/otool >/dev/null 2>&1 || ! command -v /usr/bin/install_name_tool >/dev/null 2>&1; then
    return 0
  fi

  local current
  current="$(/usr/bin/otool -L "$bin" | sed '1d' | awk '{print $1}' | grep -E '(^|/)libpq\.5\.dylib$' | head -n 1 || true)"
  if [ -n "$current" ] && [ "$current" != "$want" ]; then
    /usr/bin/install_name_tool -change "$current" "$want" "$bin"
  fi
}

# --- Linux: set RPATH with patchelf for relocatability -----------------------

fix_linux() {
  if ! command -v patchelf >/dev/null 2>&1; then
    echo "patchelf not found; cannot fix Linux RPATH" >&2
    exit 1
  fi

  # Binaries in bin/: look for libs in ../lib
  for f in "$STAGE"/bin/*; do
    [ -f "$f" ] && patchelf --set-rpath '$ORIGIN/../lib' "$f"
  done

  # Shared libs in lib/*.so*: look for sibling libs
  for f in "$STAGE"/lib/*.so*; do
    [ -f "$f" ] && patchelf --set-rpath '$ORIGIN' "$f"
  done

  # Extension libs in lib/postgresql/*.so: look in parent lib/
  if [ -d "$STAGE/lib/postgresql" ]; then
    for f in "$STAGE"/lib/postgresql/*.so; do
      [ -f "$f" ] && patchelf --set-rpath '$ORIGIN/..' "$f"
    done
  fi
}

# --- Platform dispatch -------------------------------------------------------

case "$PLATFORM" in
  darwin)
    fix_darwin "$STAGE/bin/initdb"
    fix_darwin "$STAGE/bin/pg_isready"
    ;;
  linux)
    fix_linux
    ;;
  *)
    echo "Unknown PLATFORM: $PLATFORM" >&2
    exit 1
    ;;
esac

echo "Packaging txz: $TXZ_OUT"
tar -cJf "$TXZ_OUT" -C "$STAGE" bin lib share

echo "Packaging jar: $JAR_OUT"
mkdir -p "$TMP/jar/META-INF"
printf "Manifest-Version: 1.0\n" > "$TMP/jar/META-INF/MANIFEST.MF"
cp "$TXZ_OUT" "$TMP/jar/$(basename "$TXZ_OUT")"

# A .jar is a zip; we avoid requiring the JDK `jar` tool.
ZIP="${ZIP:-}"
if [ -z "$ZIP" ]; then
  if [ -x /usr/bin/zip ]; then
    ZIP=/usr/bin/zip
  else
    ZIP=zip
  fi
fi
(cd "$TMP/jar" && "$ZIP" -q -r "$JAR_OUT" .)
