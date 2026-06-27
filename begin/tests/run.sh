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

# Mount begin/ at /code; the image's entrypoint is bats itself.
exec docker run --rm \
  -v "${begin_dir}:/code:ro" \
  "${IMAGE}" \
  /code/tests "$@"
