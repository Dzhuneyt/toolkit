# launch.sh — composes the pure naming decision with the tmux seam.
# Depends on session.sh (unique_session_name) and tmux.sh (create/attach).

# launch_session <abs-dir>
# Resolves the collision-safe session name, then either attaches to the existing
# session for this project or creates and tags a new one.
launch_session() {
  local dir="$1"
  local decision action name
  decision="$(unique_session_name "$dir")"
  action="${decision%% *}"
  name="${decision#* }"

  if [[ "$action" == "attach" ]]; then
    attach_session "$name"
    return
  fi

  create_session "$name" "$dir"
}
