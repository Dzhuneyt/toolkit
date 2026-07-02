# tmux.sh — the tmux seam. Every tmux invocation lives here so the rest of the
# code stays pure and testable; tests replace `tmux` with a fake on PATH.
#
# Targeting note: we deliberately do NOT use tmux's `=` exact-match target
# prefix. tmux supports it inconsistently — `set-option`/`show-options` reject
# or silently ignore `-t "=name"` (you get "no such session" or an empty read),
# even though `has-session` accepts it. So existence is checked by EXACT
# enumeration (immune to prefix matching), and all other commands target by
# plain name — which is safe because tmux resolves an exact name match before
# any prefix match, and we only target names we've just created or confirmed.

# The per-session user option that records which project a session belongs to.
# It is the session's identity card — names can collide, paths cannot.
BEGIN_PATH_OPT='@begin_path'

# session_exists <name> — exit 0 iff a session with that EXACT name exists.
# Enumerate names and match the whole line; this avoids tmux prefix matching
# (e.g. "web" must NOT match "website") and handles "no server running" (the
# list is empty, so grep fails → not found).
session_exists() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -qxF -- "$1"
}

# session_path <name> — prints the absolute project path stored on the session
# (empty if unset). Call only after session_exists is true for <name>, so the
# plain-name target resolves to that exact session.
session_path() {
  tmux show-options -t "$1" -qv "$BEGIN_PATH_OPT" 2>/dev/null
}

# start_session <name> <abs-dir>
# Creates a DETACHED session in <abs-dir> running Claude Code such that the
# session SURVIVES Claude exiting (drops to an interactive shell), then tags it
# with its project path. Split out from create_session so it can be exercised
# against a real tmux without the interactive attach.
start_session() {
  local name="$1" dir="$2"
  tmux new-session -d -s "$name" -c "$dir" 'claude; exec "$SHELL"'
  tmux set-option -t "$name" "$BEGIN_PATH_OPT" "$dir"
}

# create_session <name> <abs-dir> — start it, then attach.
create_session() {
  start_session "$1" "$2"
  attach_session "$1"
}

# attach_session <name> — attach to an existing session.
attach_session() {
  tmux attach-session -t "$1"
}
