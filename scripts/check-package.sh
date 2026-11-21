#!/usr/bin/env bash
set -euo pipefail

log_dir=${LOG_DIR:-${RUNNER_TEMP:-/tmp}}
mkdir -p "$log_dir"

nix flake check --print-build-logs 2>&1 | tee "$log_dir/flake-check.log"
