#!/usr/bin/env bash
set -euo pipefail

: "${BRANCH:?BRANCH is required}"
: "${CURRENT:?CURRENT is required}"
: "${LATEST:?LATEST is required}"
: "${RELEASE:?RELEASE is required}"
: "${DEB_URL:?DEB_URL is required}"
: "${SHA512:?SHA512 is required}"
: "${REPO:?REPO is required}"
: "${BASE_BRANCH:?BASE_BRANCH is required}"

tmp=${RUNNER_TEMP:-$(mktemp -d)}
body="$tmp/pr-body.md"

gh label create automated-update \
  --color 0e8a16 \
  --description "Automated Yandex Music update" 2>/dev/null || true

{
  echo "## Yandex Music \`$LATEST\`"
  echo
  echo "- Previous version: \`$CURRENT\`"
  echo "- Release date: $RELEASE"
  echo "- Deb: $DEB_URL"
  echo "- SHA-512 (base64): \`$SHA512\`"
  echo
  echo "Automated checks passed:"
  echo
  echo "- \`nix flake check\` (build + ldd)"
  echo "- headless smoke test: app reached \`desktop:application:ready\` and stayed alive for 20s"
  echo
  echo "### Manual check"
  echo
  echo "\`\`\`bash"
  echo "nix run \"github:$REPO?ref=$BRANCH\""
  echo "\`\`\`"
} > "$body"

gh pr create --draft \
  --base "$BASE_BRANCH" \
  --head "$BRANCH" \
  --title "yandex-music: $CURRENT -> $LATEST" \
  --body-file "$body" \
  --label automated-update
