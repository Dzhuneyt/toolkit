# tmux.sh — the tmux seam. Every tmux invocation lives here so the rest of the
# code stays pure and testable; tests replace `tmux` with a fake on PATH.

# The per-session user option that records which project a session belongs to.
# It is the session's identity card — names can collide, paths cannot.
BEGIN_PATH_OPT='@begin_path'

# session_exists <name> — exit 0 if a session with that exact name exists.
session_exists() {
  tmux has-session -t "=$1" 2>/dev/null
}

# session_path <name> — prints the absolute project path stored on the session
# (empty if unset). Used to tell a real collision from "same project, reattach".
session_path() {
  tmux show-options -t "=$1" -qv "$BEGIN_PATH_OPT" 2>/dev/null
}

# create_session <name> <abs-dir>
# Creates a detached session in <abs-dir> running Claude Code such that the
# session SURVIVES Claude exiting (drops to an interactive shell), tags it with
# its project path, then attaches.
create_session() {
  local name="$1" dir="$2"
  tmux new-session -d -s "$name" -c "$dir" 'claude; exec "$SHELL"'
  tmux set-option -t "=$name" "$BEGIN_PATH_OPT" "$dir"
  tmux attach-session -t "=$name"
}

# attach_session <name> — attach to an existing session.
attach_session() {
  tmux attach-session -t "=$1"
}
