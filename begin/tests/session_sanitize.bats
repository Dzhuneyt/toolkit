#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/session.sh"
}

@test "sanitize_name: leaves a plain name unchanged" {
  run sanitize_name "web"
  assert_success
  assert_output "web"
}

@test "sanitize_name: replaces dots with underscores" {
  run sanitize_name "foo.bar"
  assert_success
  assert_output "foo_bar"
}

@test "sanitize_name: replaces colons with underscores" {
  run sanitize_name "foo:bar"
  assert_success
  assert_output "foo_bar"
}

@test "sanitize_name: replaces a mix of dots and colons" {
  run sanitize_name "a.b:c.d"
  assert_success
  assert_output "a_b_c_d"
}

@test "session_name_for: derives the candidate from a directory basename" {
  run session_name_for "/home/user/projects/acme/web"
  assert_success
  assert_output "web"
}

@test "session_name_for: sanitizes the derived basename" {
  run session_name_for "/home/user/projects/my.app"
  assert_success
  assert_output "my_app"
}

@test "session_name_for: handles a trailing slash" {
  run session_name_for "/home/user/projects/web/"
  assert_success
  assert_output "web"
}
