# guards.sh — preconditions checked before doing any real work.

# assert_not_in_tmux
# Running tmux inside tmux is almost always a mistake (you meant to detach
# first). Bail clearly instead of nesting.
assert_not_in_tmux() {
  if [[ -n "${TMUX:-}" ]]; then
    printf 'begin: already inside a tmux session — detach first (Ctrl-b d)\n' >&2
    return 1
  fi
}

# require_tools
# tmux and claude are mandatory; fail with a clear, specific message naming the
# missing one. (fzf and zoxide are optional and handled by their callers.)
require_tools() {
  local tool
  for tool in tmux claude; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'begin: required tool not found on PATH: %s\n' "$tool" >&2
      return 1
    fi
  done
}
