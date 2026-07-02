## Why

Across a multi-box dev setup (a laptop plus a few always-on local and cloud machines), git clones live in different places with different layouts, and Claude Code sessions die on disconnect. There's no single, muscle-memory command to find a project on the current box and drop into a durable Claude Code session inside it. `begin <query>` provides that — one tiny script, identical on every box, that resolves a project directory and attaches to (or creates) a persistent tmux session running Claude Code.

## What Changes

- New `begin` bash script (target: `~/bin/begin`, `chmod +x`) — a **purely local** project launcher.
- **No transport logic**: the script does NOT handle SSH/mosh/Tailscale. The user gets onto a box themselves; `begin` only ever operates on local directories and the local tmux server. The same script is synced to each box.
- **Fuzzy project resolution**: `begin prov` searches downward from the current directory (infinite depth, pruning noise dirs like `node_modules`/`.git`) for directories whose name contains the query. 0 matches → zoxide fallback → error; 1 match → use it; 2+ matches → interactive picker (fzf if present, else numbered list).
- **Persistent sessions (Mode B)**: the tmux session runs `claude; exec $SHELL` so it survives Claude exiting — the workspace stays alive with a shell underneath.
- **Collision-safe session naming**: session name defaults to the resolved directory's basename. Each session is tagged with its absolute path via a tmux user option (`@begin_path`). On a name collision, the stored path is compared — same path → idempotent reattach; different path → the name is lengthened and re-checked.
- **Nested-tmux guard**: if `$TMUX` is set, bail out immediately with an error (running tmux inside tmux is treated as a mistake).
- **Help**: no args (or `-h`/`--help`) prints usage and exits.
- Session names are sanitized (tmux-special characters `.` and `:` replaced).
- **Modular structure, not a monolith**: logic is decomposed into small single-responsibility units (resolution, ranking/selection, session naming/identity, tmux orchestration, usage) composed by a thin `begin` entrypoint. Pure logic is separated from side-effecting tmux calls so it can be unit-tested in isolation.
- **Unit tests**: a test suite (bats-core) covers the pure units — query matching/ranking, match-count branching, session-name sanitization, and collision/disambiguation logic — with tmux interactions isolated behind seams that tests can stub.

## Capabilities

### New Capabilities
- `begin-launcher`: Local CLI that fuzzily resolves a project directory on the current box and attaches to or creates a persistent, collision-safe tmux session running Claude Code inside it.

### Modified Capabilities
<!-- None — this is a net-new standalone script. -->

## Impact

- New file: `begin` script (installed to `~/bin/begin`, must be on `PATH`).
- Runtime dependencies: `bash`, `tmux`, `claude` (Claude Code CLI). Optional: `fzf` (nicer picker), `zoxide` (fallback resolution). The script must degrade gracefully when the optional tools are absent.
- Dev/test dependency: `bats-core` (bash unit testing), executed via the official `bats/bats` Docker image (`tests/run.sh`) — no host install, no git submodules. Multiple sourced library files plus a thin entrypoint instead of a single script.
- No changes to existing code or systems. Distribution of the script across boxes is out of scope for this change (handled separately, e.g. dotfiles sync).
