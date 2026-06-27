#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/session.sh"
}

# lengthen <abs-dir> <depth>
# Builds a session name from the last <depth> path segments, joined with '_'
# and sanitized. depth 1 = basename; each bump prepends one more parent
# segment. This is the pure transform the collision loop calls with an
# increasing depth.

@test "lengthen: depth 1 is the basename" {
  run lengthen "/home/user/projects/acme/web" 1
  assert_output "web"
}

@test "lengthen: depth 2 prepends the parent segment" {
  run lengthen "/home/user/projects/acme/web" 2
  assert_output "acme_web"
}

@test "lengthen: depth 3 prepends two parent segments (repeated bump)" {
  run lengthen "/home/user/projects/acme/web" 3
  assert_output "projects_acme_web"
}

@test "lengthen: sanitizes each segment" {
  run lengthen "/home/user/my.dir/my.app" 2
  assert_output "my_dir_my_app"
}

@test "lengthen: depth beyond available segments clamps to the full path" {
  run lengthen "/a/b" 9
  assert_output "a_b"
}

@test "lengthen: trailing slash is ignored" {
  run lengthen "/home/user/projects/acme/web/" 2
  assert_output "acme_web"
}
