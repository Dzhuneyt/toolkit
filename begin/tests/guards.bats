#!/usr/bin/env bats

load test_helper/common

setup() {
  _common_setup
  source "${BEGIN_LIB}/guards.sh"
  source "${BEGIN_LIB}/usage.sh"
}

@test "assert_not_in_tmux: passes when TMUX is unset" {
  unset TMUX
  run assert_not_in_tmux
  assert_success
}

@test "assert_not_in_tmux: fails and warns when TMUX is set" {
  TMUX="/tmp/tmux-1000/default,1,0"
  run assert_not_in_tmux
  assert_failure
  assert_output --partial "already inside a tmux session"
}

@test "require_tools: fails clearly when a required tool is missing" {
  # Deterministic regardless of what the environment actually has installed:
  # tmux reports present, claude reports missing.
  run bash -c "source '${BEGIN_LIB}/guards.sh'
    command() {
      if [ \"\$1\" = -v ]; then
        case \"\$2\" in
          tmux) return 0 ;;
          claude) return 1 ;;
        esac
      fi
      builtin command \"\$@\"
    }
    require_tools"
  assert_failure
  assert_output --partial "claude"
}

@test "usage: mentions the query argument and help flag" {
  run usage
  assert_success
  assert_output --partial "begin <query>"
  assert_output --partial "--help"
}

@test "usage: warns against running from ~ or /" {
  run usage
  assert_output --partial "not from ~ or /"
}
