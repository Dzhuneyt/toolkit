# session.sh — pure logic for tmux session naming and collision-safe disambiguation.
#
# These functions never call tmux. The collision loop depends on two seams,
# session_exists() and session_path(), which are provided by lib/tmux.sh at
# runtime and stubbed in unit tests. Keeping the logic pure here is what makes
# the create/attach/disambiguate decision testable without a live tmux server.

# sanitize_name <name>
# tmux treats '.' and ':' specially in session names; replace them so any
# basename is a valid session name.
sanitize_name() {
  local name="$1"
  printf '%s' "${name//[.:]/_}"
}

# session_name_for <absolute-dir>
# Candidate session name = sanitized basename of the directory.
session_name_for() {
  local dir="${1%/}"
  sanitize_name "${dir##*/}"
}

# lengthen <absolute-dir> <depth>
# Builds a session name from the last <depth> path segments joined with '_'
# and sanitized. depth 1 = basename; each increment prepends one more parent
# segment. Depth past the number of available segments clamps to the full path.
# Pure: the collision loop calls this with an increasing depth to disambiguate.
lengthen() {
  local dir="${1%/}" depth="$2"
  local IFS='/'
  # Leading slash yields an empty first field; read into an array and drop it.
  read -r -a segments <<<"$dir"
  local clean=()
  local seg
  for seg in "${segments[@]}"; do
    [[ -n "$seg" ]] && clean+=("$seg")
  done

  local total="${#clean[@]}"
  (( depth > total )) && depth="$total"

  local start=$(( total - depth ))
  local name=""
  local i
  for (( i = start; i < total; i++ )); do
    if [[ -z "$name" ]]; then
      name="${clean[i]}"
    else
      name="${name}_${clean[i]}"
    fi
  done

  sanitize_name "$name"
}

# unique_session_name <absolute-dir>
# Resolves the collision/identity loop and prints "<action> <name>":
#   create <name> — no session holds this name; caller should create + tag it
#   attach <name> — a session with this name already holds this exact project
#
# Identity is the absolute path stored as @begin_path (read via session_path);
# the name only lengthens when a shorter name is taken by a DIFFERENT project.
# Depends on the seams session_exists()/session_path() from lib/tmux.sh.
unique_session_name() {
  local dir="${1%/}"
  local depth=1
  local candidate

  while true; do
    candidate="$(lengthen "$dir" "$depth")"

    if ! session_exists "$candidate"; then
      printf 'create %s' "$candidate"
      return 0
    fi

    if [[ "$(session_path "$candidate")" == "$dir" ]]; then
      printf 'attach %s' "$candidate"
      return 0
    fi

    # Name taken by a different project — lengthen and retry. Guard against an
    # unbounded loop if the path runs out of segments to prepend.
    local next="$(lengthen "$dir" "$(( depth + 1 ))")"
    if [[ "$next" == "$candidate" ]]; then
      printf 'attach %s' "$candidate"
      return 0
    fi
    depth=$(( depth + 1 ))
  done
}
