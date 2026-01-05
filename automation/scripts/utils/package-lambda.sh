#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/functions/dist"
mkdir -p "$OUT"

find "$ROOT/functions" -maxdepth 1 -mindepth 1 -type d -not -name dist | while read -r dir; do
  name=$(basename "$dir")
  zipfile="$OUT/${name}.zip"
  (cd "$dir" && zip -r9 "$zipfile" . >/dev/null)
  echo "Packaged $name -> $zipfile"
done

