#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=${RUNNER_TEMP:-$(mktemp -d)}

: "${LATEST:?LATEST is required}"
: "${DEB_FILE:?DEB_FILE is required}"
: "${EXPECTED_SHA512:?EXPECTED_SHA512 is required}"
: "${EXPECTED_SIZE:?EXPECTED_SIZE is required}"

if ! [[ $DEB_FILE =~ ^[A-Za-z0-9._-]+\.deb$ ]]; then
  echo "invalid deb file name: $DEB_FILE" >&2
  exit 1
fi

deb_url="https://desktop.app.music.yandex.net/stable/$DEB_FILE"
deb="$tmp/$DEB_FILE"

curl -fL --retry 3 --retry-all-errors -o "$deb" "$deb_url"

actual_size=$(stat -c%s "$deb")
if [ "$actual_size" != "$EXPECTED_SIZE" ]; then
  echo "size mismatch: expected $EXPECTED_SIZE, got $actual_size" >&2
  exit 1
fi

actual_sha512=$(openssl dgst -sha512 -binary "$deb" | base64 -w0)
if [ "$actual_sha512" != "$EXPECTED_SHA512" ]; then
  echo "sha512 mismatch" >&2
  echo "expected: $EXPECTED_SHA512" >&2
  echo "actual:   $actual_sha512" >&2
  exit 1
fi

sri="sha512-$EXPECTED_SHA512"

jq --arg version "$LATEST" --arg hash "$sri" \
  '.version = $version | .hash = $hash' \
  "$root/version.json" > "$tmp/version.json"
mv "$tmp/version.json" "$root/version.json"

jq -e --arg version "$LATEST" --arg hash "$sri" \
  '.version == $version and .hash == $hash and length == 2' \
  "$root/version.json" >/dev/null

git -C "$root" diff --check
git -C "$root" diff -- version.json

changed=$(git -C "$root" status --porcelain)
if [ "$changed" != " M version.json" ]; then
  echo "unexpected working tree changes:" >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "url=$deb_url"
    echo "path=$deb"
    echo "sri=$sri"
  } >> "$GITHUB_OUTPUT"
fi

echo "Downloaded $deb_url ($actual_size bytes)"
echo "SRI hash: $sri"
