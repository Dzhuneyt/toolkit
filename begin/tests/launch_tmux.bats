#!/usr/bin/env bats

load test_helper/common

# These tests assert the create/attach/disambiguate DECISIONS by replacing the
# real `tmux` with a fake on PATH that records its args and answers
# has-session / show-options from small state files. No tmux server runs.

setup() {
  _common_setup

  WORK="$(mktemp -d)"
  TMUX_LOG="${WORK}/tmux.log"
  SESSIONS="${WORK}/sessions"   # one existing session name per line
  PATHS="${WORK}/paths"         # "name<TAB>abs-path" per line
  : >"${TMUX_LOG}"
  : >"${SESSIONS}"
  : >"${PATHS}"
  export TMUX_LOG SESSIONS PATHS

  # Build the fake tmux.
  mkdir -p "${WORK}/bin"
  cat >"${WORK}/bin/tmux" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TMUX_LOG"
sub="$1"; shift
# Pull a -t target (form "=name") out of the remaining args.
target=""
while [ $# -gt 0 ]; do
  [ "$1" = "-t" ] && { target="$2"; shift 2; continue; }
  shift
done
name="${target#=}"
case "$sub" in
  has-session)
    grep -qx "$name" "$SESSIONS" && exit 0 || exit 1 ;;
  show-options)
    line="$(grep -P "^${name}\t" "$PATHS" 2>/dev/null || grep "^${name}	" "$PATHS")"
    printf '%s' "${line#*$'\t'}" ; exit 0 ;;
  new-session|set-option|attach-session)
    exit 0 ;;
  *) exit 0 ;;
esac
FAKE
  chmod +x "${WORK}/bin/tmux"
  PATH="${WORK}/bin:${PATH}"

  source "${BEGIN_LIB}/session.sh"
  source "${BEGIN_LIB}/tmux.sh"
  source "${BEGIN_LIB}/launch.sh"
}

teardown() {
  rm -rf "${WORK}"
}

@test "free name: creates a new session, tags it, and attaches" {
  run launch_session "/home/user/projects/acme/web"
  assert_success

  run cat "${TMUX_LOG}"
  assert_line --partial 'new-session -d -s web -c /home/user/projects/acme/web claude; exec "$SHELL"'
  assert_line --partial 'set-option -t =web @begin_path /home/user/projects/acme/web'
  assert_line --partial 'attach-session -t =web'
}

@test "same project: existing session with matching path -> attach, no new-session" {
  printf 'web\n' >"${SESSIONS}"
  printf 'web\t/home/user/projects/acme/web\n' >"${PATHS}"

  run launch_session "/home/user/projects/acme/web"
  assert_success

  run cat "${TMUX_LOG}"
  assert_line --partial 'attach-session -t =web'
  refute_line --partial 'new-session'
}

@test "real collision: shorter name is a foreign project -> create the bumped name" {
  printf 'web\n' >"${SESSIONS}"
  printf 'web\t/somewhere/else/web\n' >"${PATHS}"

  run launch_session "/home/user/projects/acme/web"
  assert_success

  run cat "${TMUX_LOG}"
  assert_line --partial 'new-session -d -s acme_web -c /home/user/projects/acme/web'
  assert_line --partial 'set-option -t =acme_web @begin_path /home/user/projects/acme/web'
}
