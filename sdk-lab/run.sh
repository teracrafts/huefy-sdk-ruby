#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
RUNNER="${SCRIPT_DIR}/run.rb"

cd "${SDK_ROOT}"

if [ -x /opt/homebrew/opt/ruby/bin/ruby ]; then
  exec /opt/homebrew/opt/ruby/bin/ruby "${RUNNER}" "$@"
fi

if command -v bundle >/dev/null 2>&1; then
  exec bundle exec ruby "${RUNNER}" "$@"
fi

if command -v ruby >/dev/null 2>&1; then
  exec ruby "${RUNNER}" "$@"
fi

echo "A compatible Ruby runtime is required to run the Ruby SDK lab." >&2
exit 1
