#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?PREFIX required}"

INITDB="$PREFIX/bin/initdb"
PG_CTL="$PREFIX/bin/pg_ctl"
PSQL="$PREFIX/bin/psql"

if [ ! -x "$INITDB" ] || [ ! -x "$PG_CTL" ] || [ ! -x "$PSQL" ]; then
  echo "Expected initdb/pg_ctl/psql under $PREFIX/bin"
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DATA="$WORKDIR/pgdata"
LOG="$WORKDIR/postgres.log"

"$INITDB" -D "$DATA" --username=postgres --auth=trust --no-instructions >/dev/null
"$PG_CTL" -D "$DATA" -l "$LOG" -o "-p 54321 -h 127.0.0.1" start >/dev/null

set +e
"$PSQL" -h 127.0.0.1 -p 54321 -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1
STATUS=$?
set -e

"$PG_CTL" -D "$DATA" -m fast stop >/dev/null

if [ "$STATUS" -ne 0 ]; then
  echo "Failed to CREATE EXTENSION vector; install likely missing pgvector artifacts."
  echo "Log:"
  tail -n 80 "$LOG" || true
  exit 1
fi

echo "OK: pgvector extension loads"

