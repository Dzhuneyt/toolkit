#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/select.sh"
}

LIST="/p/acme/web
/p/archive/web"

@test "nth_line: picks the first entry" {
  run nth_line 1 "$LIST"
  assert_success
  assert_output "/p/acme/web"
}

@test "nth_line: picks the second entry" {
  run nth_line 2 "$LIST"
  assert_success
  assert_output "/p/archive/web"
}

@test "nth_line: rejects an out-of-range index" {
  run nth_line 3 "$LIST"
  assert_failure
}

@test "nth_line: rejects a non-numeric index" {
  run nth_line abc "$LIST"
  assert_failure
}

@test "nth_line: rejects zero" {
  run nth_line 0 "$LIST"
  assert_failure
}

@test "choose_interactive: numbered fallback reads a choice from stdin" {
  # Stub `command` so `command -v fzf` reports missing, forcing the prompt path.
  run bash -c "source '${BEGIN_LIB}/select.sh'; command() { [ \"\$2\" = fzf ] && return 1; builtin command \"\$@\"; }; printf '2\n' | choose_interactive '$LIST'"
  assert_success
  assert_output --partial "/p/archive/web"
}
