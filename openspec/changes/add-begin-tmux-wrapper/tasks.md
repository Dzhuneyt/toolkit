## 1. Component scaffolding (repo containment)

- [x] 1.1 Create the self-contained `begin/` subdirectory at the repo root (no source/lib/test files at the repo root)
- [x] 1.2 Create `begin/lib/` and `begin/tests/` directories
- [x] 1.3 Add `begin/README.md` with the clone + symlink install flow (`git clone` → `chmod +x` → `ln -s …/begin/begin ~/bin/begin` → confirm `PATH`) and usage for this tool only
- [x] 1.4 Place `lib/` as a sibling of the entrypoint inside `begin/` (resolved Open Question)
- [x] 1.5 Run bats-core tests via Docker (`tests/run.sh` → official `bats/bats` image) — no host install, no submodules; self-contained assertion shim in `tests/test_helper/common.bash` avoids `bats-assert`/`bats-support`

## 2. Pure logic units (test-first)

- [x] 2.1 Write bats tests for `sanitize_name()` (`.` and `:` → safe char; basename derivation)
- [x] 2.2 Implement `lib/session.sh` `sanitize_name()` to pass 2.1
- [x] 2.3 Write bats tests for `match.sh` query filtering (substring match) and match-count branching (0 / 1 / 2+)
- [x] 2.4 Implement `lib/match.sh` `filter_by_query()` / `pick_match()` to pass 2.3
- [x] 2.5 Write bats tests for the `lengthen()` disambiguation transform (parent-segment prepend; repeated bumps)
- [x] 2.6 Implement `lengthen()` to pass 2.5
- [x] 2.7 Write bats tests for `unique_session_name()` collision/identity loop using a stubbed `session_exists`/`session_path` (same path → reattach name; different path → bumped name; free name → as-is)
- [x] 2.8 Implement `unique_session_name()` in `lib/session.sh` to pass 2.7

## 3. Side-effecting units

- [x] 3.1 Implement `lib/resolve.sh` `find_candidates()`: downward `find` from CWD, unbounded depth, prune `node_modules`/`.git`/`vendor`/`dist`/`build`
- [x] 3.2 Implement zoxide fallback path in resolution (used only when 0 matches; no-op if zoxide absent)
- [x] 3.3 Implement `lib/select.sh` `choose_interactive()`: fzf when available, numbered-list + read prompt fallback
- [x] 3.4 Implement `lib/tmux.sh` `create_session()` (runs `claude; exec $SHELL`, `-c` resolved dir) and set `@begin_path` user option
- [x] 3.5 Implement `lib/tmux.sh` `session_exists()`, `session_path()` (read `@begin_path` for a named session), `attach_session()`
- [x] 3.6 Write bats tests for create/attach decisions using a fake `tmux` on `PATH` that records args (asserts reattach vs. create vs. disambiguate without a real tmux server)

## 4. Guards and usage

- [x] 4.1 Implement `lib/guards.sh` `assert_not_in_tmux()` (error + non-zero when `$TMUX` set)
- [x] 4.2 Implement `lib/guards.sh` `require_tools()` (require `tmux`, `claude`; clear error naming the missing one)
- [x] 4.3 Implement `lib/usage.sh` usage/help text
- [x] 4.4 Write bats tests for guards (in-tmux bail, missing required tool) and usage (no-args, `-h`, `--help`)

## 5. Entrypoint composition

- [x] 5.1 Implement a portable symlink self-resolver in the entrypoint (no `readlink -f`; works on BSD/macOS and GNU/Linux) to locate the real `begin/` dir when invoked through a `~/bin` symlink
- [x] 5.2 Write a bats test for the symlink resolver (invoke via a temp symlink from an unrelated CWD; assert `lib/` is found; assert direct-path invocation also works)
- [x] 5.3 Implement the thin `begin` entrypoint: self-resolve, `source` `lib/*`, parse args, run guards, then compose resolve → match → select → name → create/attach
- [x] 5.4 Wire the no-args / `-h` / `--help` short-circuit to usage before any resolution
- [x] 5.5 Ensure bash 3.2 (macOS) compatibility — avoid or guard bash-4-only features so the same script runs on Mac and Linux boxes

## 6. Verification

- [x] 6.1 Run the full bats suite under `begin/tests/` — all green
- [x] 6.2 Manual acceptance: from a projects parent dir, `begin <query>` resolves, creates a session, runs Claude
- [ ] 6.3 Manual acceptance: detach (Ctrl-b d), re-run `begin <query>` → idempotent reattach to the same session (no duplicate) — _needs a real tmux + terminal; reattach decision is covered by `launch_tmux.bats`_
- [ ] 6.4 Manual acceptance: let Claude exit inside the session → session survives with a shell in the project dir — _needs real tmux + claude; the `claude; exec "$SHELL"` command is asserted in `launch_tmux.bats`_
- [x] 6.5 Manual acceptance: two same-basename projects → picker disambiguates dir AND session name lengthens (no wrong attach)
- [x] 6.6 Manual acceptance: `begin` inside an existing tmux session → bails out with error
- [x] 6.7 Manual acceptance (clean-machine install): `git clone` + `chmod +x` + `ln -s …/begin/begin ~/bin/begin`, then `begin <query>` works from an unrelated dir (validates symlink resolution end to end)
- [x] 6.8 CI: add `.github/workflows/begin-tests.yml` (path-filtered to `begin/**`, ubuntu-latest, runs `bash begin/tests/run.sh`); verified `run.sh` propagates the bats exit code (fail → 1, pass → 0)
