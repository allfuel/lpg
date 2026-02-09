#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?PREFIX required}"
TXZ_OUT="${2:?TXZ_OUT required}"
JAR_OUT="${3:?JAR_OUT required}"

OUTDIR="$(cd "$(dirname "$TXZ_OUT")" && pwd)"
mkdir -p "$OUTDIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Packaging txz: $TXZ_OUT"
tar -cJf "$TXZ_OUT" -C "$PREFIX" .

echo "Packaging jar: $JAR_OUT"
mkdir -p "$TMP/jar/META-INF"
printf "Manifest-Version: 1.0\n" > "$TMP/jar/META-INF/MANIFEST.MF"
cp "$TXZ_OUT" "$TMP/jar/$(basename "$TXZ_OUT")"

# A .jar is a zip; we avoid requiring the JDK `jar` tool.
(cd "$TMP/jar" && /usr/bin/zip -q -r "$JAR_OUT" .)

