#!/usr/bin/env bash
set -euo pipefail

: "${BRANCH:?BRANCH is required}"
: "${CURRENT:?CURRENT is required}"
: "${LATEST:?LATEST is required}"

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git switch -C "$BRANCH"
git add version.json
git commit -m "yandex-music: $CURRENT -> $LATEST"
git push --force origin "$BRANCH"

echo "Pushed $BRANCH"
