#!/usr/bin/env bash
#
# Run the claude-notify test suite inside the official bats-core Docker image.
# Nothing is installed on the host — bats lives only in the container.
#
# usage: claude-notify/tests/run.sh [extra bats args...]

set -euo pipefail

# Pin the image so test runs are reproducible across boxes.
IMAGE="bats/bats:1.11.0"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # claude-notify/tests
tool_dir="$(cd "${here}/.." && pwd)"                   # claude-notify/

# Mount claude-notify/ at /code. Install jq into the container — the dispatcher
# needs it to parse the hook payload; without it the smoke test wouldn't exercise
# the real path. Everything else the script reaches for (terminal-notifier,
# osascript, afplay) is intentionally absent here — that IS the degradation path
# the test asserts (exit 0 with no notification backend).
exec docker run --rm \
  -v "${tool_dir}:/code:ro" \
  --entrypoint sh \
  "${IMAGE}" \
  -c "apk add --no-cache jq >/dev/null 2>&1 && exec bats /code/tests $*"
