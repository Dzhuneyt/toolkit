# Shared test setup. Self-contained: implements the small subset of
# bats-support/bats-assert helpers the suite uses, so tests run on the stock
# `bats/bats` Docker image with NO extra libraries, submodules, or host install.

_common_setup() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Absolute path to begin/lib, regardless of where bats is invoked from.
  BEGIN_LIB="$(cd "${here}/../../lib" && pwd)"
  export BEGIN_LIB
}

_fail() {
  printf '%s\n' "$@" >&2
  return 1
}

# assert_success / assert_failure — check $status from the last `run`.
assert_success() {
  [[ "$status" -eq 0 ]] || _fail "expected success, got exit $status" "output: $output"
}

assert_failure() {
  [[ "$status" -ne 0 ]] || _fail "expected failure, got exit 0" "output: $output"
}

# assert_equal <actual> <expected>
assert_equal() {
  [[ "$1" == "$2" ]] || _fail "values differ:" "  actual:   $1" "  expected: $2"
}

# assert_output [--partial] <expected> — compare against $output.
assert_output() {
  if [[ "$1" == "--partial" ]]; then
    [[ "$output" == *"$2"* ]] || _fail "output does not contain:" "  $2" "actual: $output"
  else
    [[ "$output" == "$1" ]] || _fail "output mismatch:" "  actual:   $output" "  expected: $1"
  fi
}

# assert_line [--partial] <expected> — search the $lines array.
assert_line() {
  local partial=0
  [[ "$1" == "--partial" ]] && { partial=1; shift; }
  local needle="$1" line
  for line in "${lines[@]}"; do
    if (( partial )); then
      [[ "$line" == *"$needle"* ]] && return 0
    else
      [[ "$line" == "$needle" ]] && return 0
    fi
  done
  _fail "no line matched:" "  $needle"
}

# refute_line [--partial] <expected> — fail if any line matches.
refute_line() {
  local partial=0
  [[ "$1" == "--partial" ]] && { partial=1; shift; }
  local needle="$1" line
  for line in "${lines[@]}"; do
    if (( partial )); then
      [[ "$line" == *"$needle"* ]] && _fail "unexpected line present:" "  $line"
    else
      [[ "$line" == "$needle" ]] && _fail "unexpected line present:" "  $line"
    fi
  done
  return 0
}
