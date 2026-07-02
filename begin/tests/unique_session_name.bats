#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/session.sh"
}

# unique_session_name <abs-dir> resolves the collision/identity loop and prints
# "<action> <name>" where action is "attach" (session already holds this exact
# project) or "create" (name is free). The loop depends on two seams provided by
# lib/tmux.sh at runtime; here they are stubbed.
#
# session_exists <name>      -> exit 0 if a session with that name exists
# session_path   <name>      -> prints the @begin_path stored on that session

@test "free name: basename not taken -> create at basename" {
  session_exists() { return 1; }                 # nothing exists
  session_path() { :; }
  run unique_session_name "/home/user/projects/acme/web"
  assert_success
  assert_output "create web"
}

@test "same project: name taken and stored path matches -> attach, no lengthen" {
  session_exists() { [[ "$1" == "web" ]]; }
  session_path() { printf '%s' "/home/user/projects/acme/web"; }
  run unique_session_name "/home/user/projects/acme/web"
  assert_success
  assert_output "attach web"
}

@test "real collision then free: bump to parent-qualified name and create" {
  # "web" exists but points elsewhere; the depth-2 name is free.
  session_exists() { [[ "$1" == "web" ]]; }
  session_path() { printf '%s' "/home/user/other/place/web"; }
  run unique_session_name "/home/user/projects/acme/web"
  assert_success
  assert_output "create acme_web"
}

@test "real collision then same project at depth 2: attach the longer name" {
  # Both "web" and "acme_web" exist; the latter is THIS project.
  session_exists() { [[ "$1" == "web" || "$1" == "acme_web" ]]; }
  session_path() {
    case "$1" in
      web) printf '%s' "/home/user/other/place/web" ;;
      acme_web) printf '%s' "/home/user/projects/acme/web" ;;
    esac
  }
  run unique_session_name "/home/user/projects/acme/web"
  assert_success
  assert_output "attach acme_web"
}

@test "double collision: both shorter names are foreign, create at depth 3" {
  session_exists() { [[ "$1" == "web" || "$1" == "acme_web" ]]; }
  session_path() { printf '%s' "/somewhere/else/entirely/x"; }
  run unique_session_name "/home/user/projects/acme/web"
  assert_success
  assert_output "create projects_acme_web"
}
