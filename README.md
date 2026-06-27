# toolkit

A personal collection of small, self-contained tools — bash scripts, playbooks,
and other utilities. Each lives in its own top-level directory and is independent
of the others; the repo root stays minimal so new tools can be added as siblings
without stepping on each other.

## Tools

| Tool | What it does |
|------|--------------|
| [`begin/`](begin/) | Find a project under the current directory and drop into a durable Claude Code tmux session inside it. |

## Conventions

- Every tool is fully contained in its own directory (source, tests, README).
- Tests run in Docker where possible, so nothing has to be installed on the host.
- CI workflows live in `.github/workflows/` and are path-filtered per tool.
