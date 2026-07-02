# select.sh — interactive disambiguation when more than one project matches.
#
# choose_interactive is side-effecting (fzf / terminal prompt). The index->line
# mapping is factored into the pure nth_line so it can be unit-tested.

# nth_line <n> <newline-list>
# Prints the 1-based n-th line of the list. Prints nothing (and fails) if n is
# out of range or not a positive integer.
nth_line() {
  local n="$1" list="$2"
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || return 1
  printf '%s\n' "$list" | sed -n "${n}p" | grep . || return 1
}

# choose_interactive <newline-list>
# Lets the user pick one entry. Uses fzf when available; otherwise prints a
# numbered list to stderr and reads a number from the terminal. Prints the
# chosen line on stdout. Fails if nothing is chosen.
choose_interactive() {
  local list="$1"

  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "$list" | fzf --prompt='begin> ' --height=40% --reverse
    return
  fi

  local i=0 line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    i=$(( i + 1 ))
    printf '  %d) %s\n' "$i" "$line" >&2
  done <<<"$list"

  local choice
  printf 'pick [1-%d]: ' "$i" >&2
  read -r choice

  nth_line "$choice" "$list"
}
