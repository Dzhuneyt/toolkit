#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/match.sh"
}

# filter_by_query reads candidate dirs on stdin (one per line) and prints the
# ones whose basename contains the query substring.

@test "filter_by_query: single match" {
  output="$(printf '%s\n' /p/website /p/backend /p/api | filter_by_query web)"
  assert_equal "$output" "/p/website"
}

@test "filter_by_query: multiple matches preserve input order" {
  output="$(printf '%s\n' /p/server /p/service /p/api | filter_by_query ser)"
  assert_equal "$output" "/p/server
/p/service"
}

@test "filter_by_query: matches on basename only, not parent path" {
  # query 'proj' appears in the parent dir but not in any basename → no matches
  output="$(printf '%s\n' /proj/alpha /proj/beta | filter_by_query proj)"
  assert_equal "$output" ""
}

@test "filter_by_query: no matches yields empty output" {
  output="$(printf '%s\n' /p/alpha /p/beta | filter_by_query zzz)"
  assert_equal "$output" ""
}

@test "filter_by_query: substring in the middle of a basename matches" {
  output="$(printf '%s\n' /p/deployment /p/api | filter_by_query ploy)"
  assert_equal "$output" "/p/deployment"
}

# count_lines reports how many candidates a newline list holds; the entrypoint
# branches 0 / 1 / 2+ on this.

@test "count_lines: zero for empty input" {
  run count_lines ""
  assert_output "0"
}

@test "count_lines: one" {
  run count_lines "/p/website"
  assert_output "1"
}

@test "count_lines: two" {
  run count_lines "/p/a
/p/b"
  assert_output "2"
}
