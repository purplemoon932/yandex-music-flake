#!/usr/bin/env bash
set -euo pipefail

pkg=${1:?usage: smoke-test.sh <package>}
pkg=$(readlink -f "$pkg")
bin="$pkg/bin/yandexmusic"

for cmd in timeout xvfb-run dbus-run-session; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "smoke: missing $cmd" >&2
    exit 1
  fi
done

work=$(mktemp -d)
cleanup() {
  rm -rf "$work"
}
trap cleanup EXIT

unset WAYLAND_DISPLAY
unset ELECTRON_OZONE_PLATFORM_HINT
unset LD_LIBRARY_PATH

export HOME="$work/home"
export XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache"
export XDG_DATA_HOME="$work/data"
export XDG_RUNTIME_DIR="$work/run"
export XDG_SESSION_TYPE=x11
export NO_AT_BRIDGE=1

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

log="$work/smoke.log"

set +e
timeout --signal=TERM --kill-after=5s 20s \
  xvfb-run -a dbus-run-session -- \
  "$bin" --no-sandbox --disable-gpu --disable-dev-shm-usage --ozone-platform=x11 \
  >"$log" 2>&1
rc=$?
set -e

if [ -n "${SMOKE_LOG:-}" ]; then
  cp "$log" "$SMOKE_LOG" 2>/dev/null || true
fi

if [ "$rc" -ne 124 ]; then
  echo "smoke: application exited with code $rc before the 20s timeout" >&2
  tail -n 120 "$log" >&2 || true
  exit 1
fi

if ! grep -q 'desktop:application:ready' "$log"; then
  echo "smoke: application did not report desktop:application:ready" >&2
  tail -n 120 "$log" >&2 || true
  exit 1
fi

echo "smoke: OK (desktop:application:ready, stayed alive for 20s)"
