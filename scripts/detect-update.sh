#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=${RUNNER_TEMP:-$(mktemp -d)}
yml=${LATEST_YML:-"$tmp/latest-linux.yml"}

if [ -z "${LATEST_YML:-}" ]; then
  curl -fsSL --retry 3 --retry-all-errors \
    -H 'Cache-Control: no-cache' \
    https://desktop.app.music.yandex.net/stable/latest-linux.yml \
    -o "$yml"
fi

latest=$(yq -r '.version // ""' "$yml")
deb_file=$(yq -r '.files[0].url // ""' "$yml")
sha512=$(yq -r '.sha512 // ""' "$yml")
release=$(yq -r '.releaseDate // ""' "$yml")
size=$(yq -r '.files[0].size // ""' "$yml")
current=$(jq -r '.version' "$root/version.json")

if ! [[ $latest =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "invalid latest version: $latest" >&2
  exit 1
fi

expected_deb="Yandex_Music_amd64_${latest}.deb"
if [ "$deb_file" != "$expected_deb" ]; then
  echo "unexpected deb name: $deb_file (expected $expected_deb)" >&2
  exit 1
fi

if ! [[ $sha512 =~ ^[A-Za-z0-9+/=]+$ ]]; then
  echo "invalid sha512" >&2
  exit 1
fi

if ! [[ $size =~ ^[0-9]+$ ]]; then
  echo "invalid size: $size" >&2
  exit 1
fi

if ! [[ $current =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "invalid current version: $current" >&2
  exit 1
fi

if [ "$current" = "$latest" ] || \
  [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n1)" = "$current" ]; then
  update=false
else
  update=true
fi

branch="update/yandex-music-$latest"

write_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s\n' "$@" >> "$GITHUB_OUTPUT"
  fi
}

write_output \
  "current=$current" \
  "latest=$latest" \
  "deb_file=$deb_file" \
  "sha512=$sha512" \
  "release=$release" \
  "size=$size" \
  "update=$update" \
  "branch=$branch"

echo "current: $current"
echo "latest:  $latest"
echo "update:  $update"

if [ "$update" != "true" ]; then
  echo "Current version $current is up to date."
  exit 0
fi

if [ -n "${GH_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
  existing=$(gh pr list \
    --head "$branch" \
    --state open \
    --json number \
    --jq '.[0].number // empty')

  if [ -n "$existing" ]; then
    write_output "skip=true"
    echo "Open PR #$existing already exists for $latest."
    exit 0
  fi
fi
