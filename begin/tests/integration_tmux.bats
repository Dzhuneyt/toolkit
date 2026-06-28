#!/usr/bin/env bats

# Integration tests against a REAL tmux server. The fake-tmux unit tests can't
# catch tmux's quirk that the `=` exact-match target prefix is unsupported by
# `set-option`/`show-options`, so these exercise the actual seams.
#
# Skipped automatically where tmux isn't installed (e.g. the Docker CI image),
# so they add real-tmux coverage locally without breaking CI.

load test_helper/common

setup() {
  _common_setup
  command -v tmux >/dev/null 2>&1 || skip "tmux not installed"

  # Isolate from the user's tmux server: a private socket dir, and make sure
  # we're not treated as nested.
  export TMUX_TMPDIR="$(mktemp -d)"
  unset TMUX

  WORK="$(mktemp -d)"
  mkdir -p "${WORK}/web" "${WORK}/website"

  source "${BEGIN_LIB}/session.sh"
  source "${BEGIN_LIB}/tmux.sh"
}

teardown() {
  tmux kill-server 2>/dev/null || true
  rm -rf "${WORK}" "${TMUX_TMPDIR:-}"
}

@test "integration: session_exists is false with no server running" {
  run session_exists web
  assert_failure
}

@test "integration: start_session creates, tags, and is found by exact name" {
  start_session web "${WORK}/web"
  run session_exists web
  assert_success
  run session_path web
  assert_output "${WORK}/web"
}

@test "integration: exact match only — 'web' absent even when 'website' exists" {
  start_session website "${WORK}/website"
  run session_exists web
  assert_failure
  run session_exists website
  assert_success
}

@test "integration: tagging distinguishes two real same-prefix sessions" {
  start_session web "${WORK}/web"
  start_session website "${WORK}/website"
  run session_path web
  assert_output "${WORK}/web"
  run session_path website
  assert_output "${WORK}/website"
}
