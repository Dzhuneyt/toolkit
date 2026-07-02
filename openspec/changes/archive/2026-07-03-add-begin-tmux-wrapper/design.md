## Context

The user works across several machines on one private network: a laptop and a few always-on local and cloud boxes (some running Docker stacks, where Claude Code runs in project dirs). Git clones live on several of these with **different directory layouts** per box. Claude Code sessions die on disconnect, and there is no uniform command to find a project on the current box and drop into a durable session.

An earlier draft was a single monolithic script that also handled mosh/ssh transport and a hardcoded project registry. Through exploration this was deliberately stripped down: **no transport, no registry** — `begin` is a purely local launcher, synced identically to each box, that fuzzily finds a project under the CWD and attaches to (or creates) a persistent tmux session running Claude Code. The user additionally requires the code be **decomposed into small single-responsibility units** with **unit tests**, not one monster script.

## Goals / Non-Goals

**Goals:**
- A single command `begin <query>` that fuzzily resolves a project dir under the CWD and lands in a durable Claude Code tmux session.
- Identical script on every box (no per-box config).
- Persistent sessions (survive Claude exiting and disconnects).
- Collision-safe, idempotent session handling (reattach the same project; never silently attach to the wrong one).
- Modular, single-responsibility units with pure logic unit-tested in isolation.
- Self-contained inside a `begin/` subdirectory so this repo can host many unrelated tools without root-level sprawl.

**Non-Goals:**
- Any transport (ssh/mosh/Tailscale) — the user gets onto the box themselves.
- A project registry or host list.
- Distribution/sync of the script across boxes (separate concern, e.g. dotfiles).
- Companion commands (`end`, `ls`) — out of scope for this change, may follow later.

## Decisions

### Repository containment: `begin/` is one component of a multi-tool repo

This repo (`toolkit`) is intended to hold many unrelated tools over time — bash scripts, playbooks, and other artifacts not yet known. Therefore `begin` MUST be fully self-contained inside its own top-level subdirectory and MUST NOT place its source, library, or test files at the repository root. The root stays free for a top-level `README` and future sibling components.

```
toolkit/                         # repo root — stays minimal, holds many tools
  README.md                      # (root: indexes the tools; not owned by begin)
  begin/                         # ← this component, fully self-contained
    begin                        # entrypoint
    lib/...
    tests/...
    README.md                    # how to install/use just this tool
  <future-tool>/                 # later siblings live here, not nested in begin/
```

Everything below is **relative to `begin/`**, never the repo root.

### File layout: thin entrypoint + sourced library units

A `begin` entrypoint that sources small library files, each one responsibility (all under `begin/`):

```
begin/
  begin                    # entrypoint: arg parse, guards, compose the pipeline
  lib/
    usage.sh               # usage/help text
    guards.sh              # require_tools(), assert_not_in_tmux()
    resolve.sh             # find_candidates(): downward search + prune  (side-effecting: filesystem)
    match.sh               # filter_by_query(), pick_match()             (PURE: operates on a passed list)
    select.sh              # choose_interactive(): fzf or numbered list
    session.sh             # sanitize_name(), session_exists(), session_path(), unique_session_name()
    tmux.sh                # create_session(), attach_session()          (side-effecting: tmux)
  tests/
    *.bats                 # bats-core unit tests for the pure units
  README.md                # install + usage for this tool only
```

The seam that makes this testable: **pure string/list logic** (query matching, ranking/branching by match count, name sanitization, the disambiguation name-bumping algorithm) takes inputs as arguments and returns values — it never calls `tmux` or `find` directly. The **side-effecting units** (`resolve.sh`, `tmux.sh`, `select.sh`) are thin wrappers around `find`/`tmux`/`fzf`. Tests exercise the pure units directly and stub the side-effecting ones.

*Alternative considered:* one self-contained script (the original draft). Rejected per the user's explicit requirement for decomposition + unit tests; a monolith makes the pure logic untestable without spinning up a real tmux server.

### Resolution: downward `find`, prune noise, substring match

`find` from CWD with unbounded depth, pruning `node_modules`, `.git`, `vendor`, `dist`, `build`, then keep directories whose **basename contains** the query substring.

- Match count drives behavior: `0 → zoxide fallback → error`, `1 → use it`, `2+ → picker`.
- No depth cap: scope is controlled by *where* the user launches it, and pruning keeps unbounded depth fast and noise-free.
- Substring (not exact/prefix tiers): simplest possible rule; the picker absorbs all ambiguity, so no ranking logic is needed.

*Alternatives considered:* zoxide-only (fails on never-visited dirs on fresh boxes); exact/prefix/substring tiered ranking (rejected as over-engineering — the picker already disambiguates).

### Session identity: tmux user option `@begin_path`

The session **name** is a human label (basename, sanitized) that can collide; the **identity** is the absolute project path stored as a tmux user option `@begin_path` on the session.

Resolution algorithm for the session name:

```
candidate = sanitize(basename(dir))
loop:
  if no session named `candidate` exists:
      create session `candidate`, set @begin_path = abs(dir)   → attach
  else:
      stored = `tmux show-option -gqv -t candidate @begin_path`  (effectively per-session)
      if stored == abs(dir):  attach `candidate`        # same project → idempotent
      else:                   candidate = lengthen(candidate); continue   # real collision
```

This yields: shortest name when free, idempotent reattach for the same project, and a longer name only on a genuine different-project collision. The `lengthen()` transform (e.g. prepend the parent directory segment) is a **pure** function and a prime unit-test target.

*Alternative considered:* encode the full path into the name always. Rejected — ugly `tmux ls`, and the user wanted shortest-name-first.

### Install model: clone + symlink, with self-resolving entrypoint

First-time setup on a clean box: `git clone` the repo somewhere, then symlink the entrypoint onto `PATH` (`ln -s <repo>/begin/begin ~/bin/begin`). The repo is the single source of truth; `git pull` updates every box's `begin` because the symlink points back into the clone.

This forces the entrypoint to **self-resolve its real location** before sourcing `lib/`: invoked via the symlink, `$0`/`BASH_SOURCE` is the symlink path, but `lib/` lives beside the *real* file. So `lib/` is a sibling of the entrypoint inside `begin/` (resolves the earlier open question), and the entrypoint walks the symlink chain to find its real dir.

Resolution must be **portable** — macOS ships BSD `readlink` (no `-f`), and two boxes are Macs. Use a small portable resolver (a `cd "$(dirname …)" && pwd -P` loop following `readlink` one hop at a time, or `pwd -P` after `cd`), not `readlink -f`.

*Alternatives considered:* copy the script into `~/bin` instead of symlinking (rejected — `git pull` would no longer update it, defeating the single-source-of-truth model); hardcode an absolute `lib/` path (rejected — breaks the "identical script on every box" goal since clone locations differ).

### Persistence: `claude; exec $SHELL`

The session's initial command is `claude; exec $SHELL` so that when Claude exits, the session drops to an interactive shell in the project dir rather than dying. On reattach, tmux ignores the command, so no duplicate Claude is launched.

*Alternative considered:* a relaunch loop (`while true; do claude; done`) — rejected, it traps the user out of a shell. Plain `claude` — rejected, the session dies when Claude exits (the original draft's footnote bug).

### Guards

- `assert_not_in_tmux`: if `$TMUX` is set, error and exit non-zero (nested tmux treated as a mistake).
- `require_tools`: `tmux` and `claude` are required (clear error if missing); `fzf` and `zoxide` are optional with fallbacks.

### Testing: bats-core, run via Docker (no host install, no submodules)

bats-core (the maintained fork; the original `sstephenson/bats` is archived) for unit tests. Pure units are called directly with fixture inputs. Side-effecting seams are replaced by stub functions/`PATH` shims in tests (e.g. a fake `tmux` recording its args), so the disambiguation and create/attach decisions are asserted without a live tmux server.

The suite runs **inside the official `bats/bats` Docker image** via `tests/run.sh`, which mounts `begin/` read-only and invokes bats — nothing is installed on the host. To keep that image sufficient on its own, the tests do **not** depend on the `bats-assert`/`bats-support` helper libraries; instead a small self-contained assertion shim (`tests/test_helper/common.bash`) implements just the helpers used (`assert_success`, `assert_output`, `assert_line`, `refute_line`, `assert_equal`).

*Alternatives considered:* vendoring bats as git submodules (rejected — the user does not want submodules; adds `--recursive` clone friction); a host package install via brew/npm (rejected — pollutes the OS); switching to shellspec (considered for its BDD/mocking/POSIX features, but bats-core is the maintained standard and the suite already passes on it).

## Risks / Trade-offs

- **Interactive picker breaks non-interactive use** → Acceptable: `begin` is always hand-typed to start a session; not meant for pipes/scripts.
- **Unbounded `find` from a huge dir (`~`, `/`) is slow** → Mitigated by noise-pruning + the documented workflow of launching from a projects parent dir; "don't do that."
- **`lengthen()` could in theory still collide after one bump** → Mitigated by looping the existence/identity check until a free or matching name is found, not bumping just once.
- **tmux user-option scoping / target resolution** — RESOLVED. The `=` exact-match target prefix is supported inconsistently across tmux subcommands: `set-option -t "=name"` errors with "no such session" and `show-options -t "=name"` silently returns empty, even though `has-session` accepts it. The stubbed-tmux unit tests missed this because the fake accepted `=`. Fix: never use `=`; check existence by exact enumeration (`list-sessions -F '#{session_name}' | grep -qxF`, immune to prefix matching) and target all other commands by plain name (tmux resolves an exact match before any prefix match, and we only target names we just created or enumerated). Guarded by real-tmux integration tests (`tests/integration_tmux.bats`).
- **Bash portability across macOS (older bash 3.2) and Linux boxes** → Avoid bash-4-only features (associative arrays, `mapfile` where 3.2 lacks it) or guard them; the script must run identically on the macOS and Linux boxes.

## Migration Plan

Net-new, additive. First-time install on a clean box:

```
git clone <repo> ~/<path>/toolkit
chmod +x ~/<path>/toolkit/begin/begin
ln -s ~/<path>/toolkit/begin/begin  ~/bin/begin   # symlink onto PATH
# confirm ~/bin is on PATH
```

Updates: `git pull` in the clone — the symlink means every box picks up changes with no re-copy. Rollback: remove the symlink (and optionally the clone) — fully reverts.

## Open Questions

- Exact `lengthen()` transform: prepend single parent segment (`acme_web`), or append a short hash? Leaning parent-segment for readability; finalize in implementation.
- ~~Where does `lib/` live relative to the installed entrypoint?~~ **Resolved:** `lib/` is a sibling of the entrypoint inside `begin/`; the entrypoint self-resolves its symlink to find it (see "Install model" decision).
