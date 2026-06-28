#!/usr/bin/env bash
#
# Run the begin test suite inside the official bats-core Docker image.
# Nothing is installed on the host — bats lives only in the container.
#
# usage: begin/tests/run.sh [extra bats args...]

set -euo pipefail

# Pin the image so test runs are reproducible across boxes.
IMAGE="bats/bats:1.11.0"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # begin/tests
begin_dir="$(cd "${here}/.." && pwd)"                  # begin/

# Mount begin/ at /code. Install tmux into the container so the real-tmux
# integration tests actually run (they self-skip when tmux is absent). The
# unit tests are unaffected — they shadow `tmux` with a fake on PATH.
exec docker run --rm \
  -v "${begin_dir}:/code:ro" \
  --entrypoint sh \
  "${IMAGE}" \
  -c "apk add --no-cache tmux >/dev/null 2>&1 && exec bats /code/tests $*"
