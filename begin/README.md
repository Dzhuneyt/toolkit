# begin

Find a project under the current directory and drop into a durable Claude Code
tmux session inside it. **Purely local** — `begin` does no SSH/mosh/Tailscale.
You get onto a box however you like (locally, `ssh`, `mosh`), then run `begin`
there. The same script is meant to live on every box.

```
begin <query>
```

## What it does

1. **Resolve** — searches downward from the current directory (unbounded depth,
   pruning `node_modules`/`.git`/`vendor`/`dist`/`build`) for a directory whose
   name contains `<query>`.
   - 0 matches → falls back to `zoxide`, else errors
   - 1 match → uses it
   - 2+ matches → lets you pick (`fzf` if available, else a numbered list)
2. **Session** — attaches to (or creates) a tmux session for that project. The
   session runs Claude Code and **survives Claude exiting** (a shell remains
   underneath, in the project directory).
3. **Collision-safe naming** — each session is tagged with its project's
   absolute path (`@begin_path`). Re-running `begin` reattaches the *same*
   project; two projects with the same folder name get disambiguated
   automatically (the name lengthens with a parent segment).

Run it from a directory that contains your projects — not from `~` or `/`.

## Install (clean machine)

```sh
# 1. Clone
git clone git@github.com:Dzhuneyt/toolkit.git ~/src/toolkit

# 2. Make the entrypoint executable
chmod +x ~/src/toolkit/begin/begin

# 3. Symlink it onto your PATH
ln -s ~/src/toolkit/begin/begin ~/bin/begin

# 4. Confirm ~/bin is on PATH (add to your shell rc if not)
case ":$PATH:" in *":$HOME/bin:"*) echo "ok";; *) echo "add ~/bin to PATH";; esac
```

Updating every box later is just `git pull` in the clone — the symlink points
back into the repo, so there's nothing to re-copy.

## Dependencies

| Tool      | Required | Used for                                  |
|-----------|----------|-------------------------------------------|
| `bash`    | yes      | the script (kept bash-3.2 / macOS compatible) |
| `tmux`    | yes      | the persistent session                    |
| `claude`  | yes      | Claude Code, launched inside the session  |
| `fzf`     | no       | nicer picker on multiple matches          |
| `zoxide`  | no       | fallback resolution when nothing is found |

## Layout

```
begin/
  begin            # entrypoint: self-resolves its symlink, sources lib/, composes
  lib/
    usage.sh       # help text
    guards.sh      # assert_not_in_tmux, require_tools
    resolve.sh     # find_candidates (downward search + prune), zoxide_fallback
    match.sh       # filter_by_query, count_lines        (pure)
    select.sh      # choose_interactive, nth_line
    session.sh     # sanitize_name, session_name_for, lengthen, unique_session_name (pure)
    tmux.sh        # session_exists, session_path, start_session, create_session, attach_session
    launch.sh      # launch_session — composes naming + tmux
  tests/           # bats-core suite; run.sh runs it via Docker (no host install)
```

Pure logic (matching, naming, disambiguation) is separated from the
side-effecting tmux/filesystem units so it can be unit-tested in isolation.

## Running the tests

Tests run inside the official **bats-core** Docker image — nothing is installed
on the host:

```sh
begin/tests/run.sh
```

That mounts `begin/` read-only into `bats/bats` and runs the suite. Requires
only Docker. (The test helpers under `tests/test_helper/common.bash` are a small
self-contained shim, so no `bats-assert`/`bats-support` libraries are needed.)

`run.sh` also installs tmux inside the container so the real-tmux integration
tests (`tests/integration_tmux.bats`) run rather than self-skip; the remaining
unit tests shadow `tmux` with a fake on PATH.
