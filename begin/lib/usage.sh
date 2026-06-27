# usage.sh — help text.

usage() {
  cat <<'EOF'
begin — find a project under the current directory and drop into a durable
        Claude Code tmux session inside it.

usage:
  begin <query>     resolve a project whose folder name contains <query>,
                    then attach to (or create) its tmux session
  begin -h|--help   show this help

how it works:
  - searches downward from the current directory (pruning node_modules/.git/…)
  - 0 matches  → falls back to zoxide, else errors
    1 match    → uses it
    2+ matches → lets you pick (fzf if available, else a numbered list)
  - the session runs Claude Code and SURVIVES Claude exiting (a shell remains)
  - sessions are tagged with their project path, so re-running reattaches the
    same project and same-named projects get disambiguated automatically

run it from a directory that contains your projects (not from ~ or /).
EOF
}
