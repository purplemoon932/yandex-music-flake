#!/usr/bin/env bash
set -euo pipefail

log_dir=${LOG_DIR:-${RUNNER_TEMP:-/tmp}}
version=${LATEST:-unknown}
title="yandex-music update failed: $version"

tmp=${RUNNER_TEMP:-$(mktemp -d)}
body="$tmp/issue-body.md"

gh label create update-failed \
  --color b60205 \
  --description "Automated Yandex Music update failed" 2>/dev/null || true

{
  echo "## Automated update failed"
  echo
  echo "- Current version: \`${CURRENT:-unknown}\`"
  echo "- Latest version: \`${LATEST:-unknown}\`"
  echo "- Release date: ${RELEASE:-unknown}"
  echo "- Workflow run: ${RUN_URL:-unknown}"
  echo

  for log in "$log_dir/flake-check.log" "$log_dir/build.log" "$log_dir/smoke.log"; do
    if [ -f "$log" ]; then
      echo "<details><summary>$(basename "$log")</summary>"
      echo
      echo '```'
      tail -n 120 "$log" || true
      echo '```'
      echo
      echo "</details>"
      echo
    fi
  done
} > "$body"

existing=$(gh issue list \
  --state open \
  --search "in:title \"$title\"" \
  --json number \
  --jq '.[0].number // empty')

if [ -n "$existing" ]; then
  gh issue comment "$existing" --body-file "$body"
else
  gh issue create \
    --title "$title" \
    --body-file "$body" \
    --label update-failed
fi
