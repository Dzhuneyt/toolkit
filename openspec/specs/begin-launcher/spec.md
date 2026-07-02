# begin-launcher Specification

## Purpose

`begin` is a purely local CLI that fuzzily resolves a project directory under the current directory and attaches to (or creates) a persistent, collision-safe tmux session running Claude Code inside it. It does no transport (SSH/mosh) — the user gets onto a box themselves — so the same script runs unchanged on every machine. Sessions survive Claude Code exiting, and are identified by their absolute project path so re-running reattaches the same project and same-named projects are disambiguated automatically.

## Requirements

### Requirement: Local-only operation

The `begin` script SHALL operate exclusively on the local machine and the local tmux server. It MUST NOT perform any SSH, mosh, Tailscale, or other network/transport actions. The same script SHALL be runnable unchanged on every box.

#### Scenario: No transport invoked

- **WHEN** `begin <query>` is run
- **THEN** the script resolves a directory and manages a tmux session entirely locally, invoking no ssh/mosh/network commands

### Requirement: Usage on no arguments or help flag

The script SHALL print usage/help text and exit when invoked with no arguments, `-h`, or `--help`.

#### Scenario: No arguments

- **WHEN** `begin` is run with no arguments
- **THEN** usage/help text is printed and the script exits without resolving any project

#### Scenario: Help flag

- **WHEN** `begin -h` or `begin --help` is run
- **THEN** usage/help text is printed and the script exits

### Requirement: Nested tmux guard

The script SHALL refuse to run when already inside a tmux session, treating nested tmux as a mistake.

#### Scenario: Invoked inside tmux

- **WHEN** `begin <query>` is run while the `$TMUX` environment variable is set
- **THEN** the script prints an error indicating it is already inside tmux and exits non-zero without creating or attaching to any session

### Requirement: Fuzzy downward project resolution

Given a query, the script SHALL search downward from the current working directory (unbounded depth) for directories whose name contains the query substring, pruning known noise directories (such as `node_modules`, `.git`, `vendor`, `dist`, `build`) from the search.

#### Scenario: Single match

- **WHEN** exactly one non-pruned directory under the CWD has a name containing the query
- **THEN** that directory is selected without prompting

#### Scenario: No matches falls back to zoxide

- **WHEN** no directory under the CWD matches the query
- **THEN** the script queries zoxide (if available) for the query as a fallback

#### Scenario: No matches and no fallback result

- **WHEN** no directory matches and zoxide is unavailable or also returns nothing
- **THEN** the script prints a clear "not found" error and exits non-zero

#### Scenario: Noise directories are pruned

- **WHEN** a name-matching directory exists only inside a pruned directory (e.g. within `node_modules`)
- **THEN** it is NOT considered a match

### Requirement: Interactive disambiguation on multiple matches

When more than one directory matches the query, the script SHALL let the user pick one interactively, using `fzf` when available and falling back to a numbered list with a read prompt otherwise.

#### Scenario: Multiple matches with fzf

- **WHEN** two or more directories match and `fzf` is available
- **THEN** the script presents the matches in an fzf picker and uses the chosen directory

#### Scenario: Multiple matches without fzf

- **WHEN** two or more directories match and `fzf` is not available
- **THEN** the script presents a numbered list and prompts the user to pick one by number

### Requirement: Persistent session running Claude Code

The script SHALL attach to or create a tmux session whose initial command runs Claude Code such that the session survives Claude Code exiting (a shell remains underneath).

#### Scenario: Session survives Claude exit

- **WHEN** a new session is created and Claude Code later exits
- **THEN** the tmux session remains alive with an interactive shell in the resolved project directory

#### Scenario: Created in resolved directory

- **WHEN** a new session is created for the resolved project
- **THEN** the session's working directory is the resolved project directory

### Requirement: Session naming with sanitization

The default tmux session name SHALL be derived from the basename of the resolved directory, with tmux-special characters (`.` and `:`) sanitized to a safe character.

#### Scenario: Basename used as session name

- **WHEN** the resolved directory is `.../web`
- **THEN** the candidate session name is `web`

#### Scenario: Special characters sanitized

- **WHEN** the resolved directory basename contains `.` or `:`
- **THEN** those characters are replaced so the session name is valid for tmux

### Requirement: Path-based session identity and collision-safe naming

Each session created by the script SHALL be tagged with the absolute path of its project directory via a tmux user option (`@begin_path`). When a candidate session name already exists, the script SHALL compare the stored path to the resolved directory to decide between reattaching and disambiguating.

#### Scenario: Idempotent reattach to same project

- **WHEN** a session with the candidate name exists and its `@begin_path` equals the resolved absolute directory
- **THEN** the script attaches to the existing session without creating a new one

#### Scenario: Real collision disambiguates

- **WHEN** a session with the candidate name exists but its `@begin_path` differs from the resolved absolute directory
- **THEN** the script lengthens the candidate name and repeats the existence/identity check until it finds a free name or a name whose stored path matches

#### Scenario: Free name creates and tags

- **WHEN** no session with the candidate name exists
- **THEN** the script creates the session and sets its `@begin_path` to the resolved absolute directory

### Requirement: Graceful degradation on optional tools

The script SHALL function when optional tools (`fzf`, `zoxide`) are absent, and SHALL fail with a clear message when required tools (`tmux`, `claude`) are missing.

#### Scenario: Missing required tool

- **WHEN** `tmux` or `claude` is not on `PATH`
- **THEN** the script prints a clear error naming the missing tool and exits non-zero

#### Scenario: Missing optional tool

- **WHEN** `fzf` or `zoxide` is absent
- **THEN** the script still resolves and launches using its fallback behavior

### Requirement: First-time installation via clone and symlink

A clean machine SHALL be able to start using `begin` by cloning the repository and symlinking the entrypoint into a directory on `PATH` (e.g. `~/bin/begin`). The entrypoint, when invoked through such a symlink, SHALL resolve its own real location and locate its `lib/` directory relative to the real file — not relative to the symlink. Symlink resolution SHALL be portable across BSD/macOS (no `readlink -f`) and GNU/Linux.

#### Scenario: Run through a symlink on PATH

- **WHEN** the entrypoint is symlinked to a `PATH` directory and invoked by name from an unrelated working directory
- **THEN** it resolves the symlink to its real path and successfully sources its `lib/` units from beside the real file

#### Scenario: Portable symlink resolution

- **WHEN** the entrypoint resolves its own location on a system whose `readlink` lacks `-f` (BSD/macOS)
- **THEN** resolution still succeeds without relying on GNU-only flags

#### Scenario: Run directly without a symlink

- **WHEN** the entrypoint is executed by its real path (no symlink)
- **THEN** it still locates `lib/` correctly

### Requirement: Modular, testable decomposition

The implementation SHALL be decomposed into small single-responsibility units composed by a thin entrypoint, separating pure logic from side-effecting tmux/process calls so the pure logic can be unit-tested in isolation.

#### Scenario: Pure logic isolated from tmux

- **WHEN** unit tests exercise query matching/ranking, match-count branching, session-name sanitization, and collision/disambiguation logic
- **THEN** those units can be tested without invoking a real tmux server

#### Scenario: Test suite present

- **WHEN** the test suite is run
- **THEN** it exercises the pure units and passes
