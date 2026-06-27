# match.sh — pure selection logic over a list of candidate directories.
#
# No filesystem or tmux access: functions operate only on the lines they are
# given, so the 0 / 1 / 2+ branching can be unit-tested directly.

# filter_by_query <query>
# Reads candidate directory paths on stdin (one per line), prints those whose
# basename contains <query> as a substring. Input order is preserved.
filter_by_query() {
  local query="$1"
  local line base
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    base="${line##*/}"
    case "$base" in
      *"$query"*) printf '%s\n' "$line" ;;
    esac
  done
}

# count_lines <newline-separated-string>
# Counts non-empty lines. Empty/blank input counts as 0.
count_lines() {
  local input="$1"
  [[ -z "$input" ]] && { printf '0'; return; }
  printf '%s\n' "$input" | grep -c .
}
