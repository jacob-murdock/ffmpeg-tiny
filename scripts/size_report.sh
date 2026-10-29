#!/usr/bin/env bash
# Print a Markdown table of static library sizes per built preset in out/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "# Size report"
echo
echo "| Preset | Library | Bytes |"
echo "|--------|---------|------:|"
shopt -s nullglob
for dir in "$ROOT"/out/*/; do
  preset="$(basename "$dir")"
  total=0
  for a in "$dir"lib/*.a; do
    n=$(wc -c < "$a" | tr -d ' ')
    total=$((total + n))
    echo "| $preset | $(basename "$a") | $n |"
  done
  [[ $total -gt 0 ]] && echo "| $preset | **total** | **$total** |"
done
