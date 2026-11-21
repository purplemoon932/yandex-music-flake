#!/usr/bin/env bash
set -euo pipefail

log_dir=${LOG_DIR:-${RUNNER_TEMP:-/tmp}}
mkdir -p "$log_dir"

out=$(nix build .#default --no-link --print-out-paths 2> "$log_dir/build.log")

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "out=$out" >> "$GITHUB_OUTPUT"
fi

echo "Built $out"
