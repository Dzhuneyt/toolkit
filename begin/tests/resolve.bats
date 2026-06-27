#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/resolve.sh"
  source "${BEGIN_LIB}/match.sh"

  FIXTURE="$(mktemp -d)"
  mkdir -p "${FIXTURE}/acme/web"
  mkdir -p "${FIXTURE}/api"
  mkdir -p "${FIXTURE}/node_modules/web"   # must be pruned
  mkdir -p "${FIXTURE}/app/.git/web"       # must be pruned
}

teardown() {
  rm -rf "${FIXTURE}"
}

@test "find_candidates: lists real project dirs" {
  run find_candidates "${FIXTURE}"
  assert_success
  assert_line "${FIXTURE}/acme/web"
  assert_line "${FIXTURE}/api"
}

@test "find_candidates: prunes node_modules subtrees" {
  run find_candidates "${FIXTURE}"
  assert_success
  refute_line --partial "node_modules/web"
}

@test "find_candidates: prunes .git subtrees" {
  run find_candidates "${FIXTURE}"
  assert_success
  refute_line --partial ".git/web"
}

@test "find_candidates piped through filter_by_query: resolves a single match" {
  output="$(find_candidates "${FIXTURE}" | filter_by_query web)"
  assert_equal "$output" "${FIXTURE}/acme/web"
}
