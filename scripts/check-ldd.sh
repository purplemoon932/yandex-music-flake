#!/usr/bin/env bash
set -euo pipefail

pkg=${1:?usage: check-ldd.sh <package>}
pkg=$(readlink -f "$pkg")
app="$pkg/lib/yandex-music"

if [ ! -d "$app" ]; then
  echo "check-ldd: missing $app" >&2
  exit 1
fi

count=0
failed=0

while IFS= read -r -d '' file; do
  if ! readelf -h "$file" >/dev/null 2>&1; then
    continue
  fi

  if ! readelf -d "$file" 2>/dev/null | grep -q 'Dynamic section'; then
    continue
  fi

  count=$((count + 1))

  if ! output=$(ldd "$file" 2>&1); then
    echo "check-ldd: ldd failed for $file" >&2
    printf '%s\n' "$output" >&2
    failed=1
    continue
  fi

  if grep -q 'not found' <<<"$output"; then
    echo "check-ldd: missing libraries for $file" >&2
    printf '%s\n' "$output" >&2
    failed=1
  fi
done < <(find "$app" -type f -print0)

if [ "$count" -eq 0 ]; then
  echo "check-ldd: no dynamic ELF files found in $app" >&2
  exit 1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "check-ldd: OK ($count dynamic ELF files, no missing libraries)"
