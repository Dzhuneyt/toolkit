# resolve.sh — filesystem-facing project discovery.
#
# Side-effecting (runs find/zoxide). Matching is deliberately NOT done here:
# find_candidates only enumerates and prunes; the pure filter_by_query in
# match.sh decides what matches, so the matching rule lives in one tested place.

# Directory names whose subtrees are never worth descending into.
BEGIN_PRUNE_DIRS=(node_modules .git vendor dist build)

# find_candidates [root]
# Prints every directory under <root> (default: CWD), unbounded depth, skipping
# the pruned subtrees entirely. One absolute-ish path per line.
find_candidates() {
  local root="${1:-.}"
  local prune_expr=()
  local first=1
  local d
  for d in "${BEGIN_PRUNE_DIRS[@]}"; do
    if (( first )); then
      prune_expr+=(-name "$d")
      first=0
    else
      prune_expr+=(-o -name "$d")
    fi
  done

  find "$root" \( "${prune_expr[@]}" \) -prune -o -type d -print
}

# zoxide_fallback <query>
# Last-resort resolution when the downward search finds nothing. Prints zoxide's
# best match(es) for <query>, or nothing if zoxide is unavailable.
zoxide_fallback() {
  local query="$1"
  command -v zoxide >/dev/null 2>&1 || return 0
  zoxide query --list "$query" 2>/dev/null || true
}
