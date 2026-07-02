## Context

The owner runs Claude Code across several boxes and needs to know, without watching the terminal, when a session needs input or has finished. A dispatcher wired to Claude Code's `Notification` and `Stop` hooks already solves this on one Mac: desk banner + per-event sound + optional phone push. It was hardened through live testing — several macOS-specific traps were hit and worked around. But it lives only in machine-local `~/.claude/hooks/`, so it is neither reproducible nor version-controlled, and the trap knowledge exists only in comments on one machine.

This change adopts that script into the `toolkit` repo as a sibling of `begin`, following the same containment and clone + symlink install model. It is deliberately an **adoption, not a rewrite**: the live script is byte-identical to the embedded reference, and the only code changes are two portability knobs. The rigor is intentionally lighter than `begin` (a thin dispatcher has little pure logic worth unit-testing) — but not zero: one smoke test guards the single failure mode that actually bit (a hook that hangs Claude Code).

## Goals / Non-Goals

**Goals:**
- Version-control the working dispatcher so it is reproducible on any box via clone + symlink, updated with `git pull` (same model as `begin`).
- Preserve the hardened behavior verbatim; change only what portability demands.
- Make the committed artifact non-opinionated about the owner's specific terminal and Zoom by lifting those to env knobs with the current values as defaults.
- Keep the real ntfy topic (a shared secret) out of the repo.
- Capture the macOS traps as documented rules with reasons, so nobody re-discovers the `-sender` hang in production.
- Guard the non-blocking guarantee with an automated test wired into CI.

**Non-Goals:**
- Rewriting or restructuring the dispatcher (no `begin`-style multi-file decomposition — the logic doesn't warrant it).
- Additional notification channels (Slack/Discord/Telegram) — out of scope.
- Changing Claude Code's hook configuration in `settings.json`.
- Promoting the Do-Not-Disturb check to a supported feature (kept as a commented example).
- Distribution/sync of the clone across boxes (the `git pull` model handles it).

## Decisions

### Adopt byte-for-byte, then apply exactly two knobs

The live `~/.claude/hooks/notify.sh` was verified byte-identical to the embedded reference in the handoff. It is copied verbatim; the ONLY edits are the two portability knobs below. Rationale: the script earned its current shape through live testing; every line traces to a real failure mode, so unrequested "improvements" carry regression risk out of proportion to their value.

*Alternative considered:* refactor into `lib/` units with unit tests like `begin`. Rejected — the dispatcher is a linear sequence of side effects (sound, banner, push) with almost no pure logic; decomposition would add structure without testable substance.

### Portability knob 1: terminal bundle id

`term_bundle="com.cmuxterm.app"` (cmux, a Ghostty fork — the owner's terminal) becomes:

```sh
term_bundle="${CLAUDE_NOTIFY_TERM_BUNDLE:-com.cmuxterm.app}"
```

`-activate <bundle>` is what makes clicking the banner focus the waiting terminal. Hardcoded, click-to-focus silently no-ops on any other box; as a knob, another box sets one env var. Default preserves current behavior.

### Portability knob 2: mute-while-running processes

`if pgrep -x "CptHost"` (Zoom's meeting helper) becomes a declarative, configurable list:

```sh
mute_while="${CLAUDE_NOTIFY_MUTE_WHILE:-CptHost}"   # space-separated process names
```

The dispatcher suppresses all output and exits 0 if any listed process is running. The owner's Zoom-mute behavior stays the default; the committed artifact stops silently assuming everyone wants to mute on `CptHost`; per-box tuning is one env var.

The commented-out Do-Not-Disturb block **stays commented**. It reads `~/Library/DoNotDisturb/DB/Assertions.json`, an undocumented internal macOS DB whose shape changes across releases. Promoting it to a live knob invites breakage; leaving it as an example preserves the idea without shipping fragility.

*Alternative considered:* keep both hardcoded (handoff's default position). Rejected for a tool "meant to live on every box" — a committed artifact should not encode one machine's terminal and one person's Zoom as immutable facts.

### Documentation: merge the superseded README's gotchas, don't lose them

A stale `~/.claude/hooks/README.md` documents an older osascript-only version. Checked against the current terminal-notifier script, 4 of its 5 gotchas still apply verbatim and the 5th narrows:

| Gotcha | Status vs. current script |
|---|---|
| `osascript sound name` is broken → play sound via `afplay` separately | Live — it's the rationale for the separate `afplay` call |
| Non-ASCII title mojibake (AppleScript returns Mac Roman) | Live but **narrowed** to the osascript *fallback* path; terminal-notifier (primary) handles UTF-8 |
| `afplay` must be backgrounded or it blocks the hook | Live — script depends on it |
| `$CLAUDE_PROJECT_DIR` is the project root, stable across `cd` | Live, unchanged |
| Sandbox: notification daemon absent → silent success | Live — applies to both backends |

The new README merges these and **adds the three earned this round**: `-sender` hangs (blocks forever, exit 124); `-appIcon` is ignored by modern macOS for the main icon; `-group` without a preceding `-remove` updates the existing banner *silently* (no re-alert — fatal for a needs-input ping, which is why the script does `-remove` then post). The old file's sound-map table and "Customizing" section are also worth carrying.

### Testing: one bats smoke test, `begin`-parity CI

Rigor is minimal but not zero. A single bats test pipes a fake payload through the script under `timeout` and asserts prompt `exit 0`. This one test guards two requirements at once:

- **No-hang** — a reintroduced blocking flag (e.g. `-sender`) trips the `timeout` and fails (exit 124 ≠ 0).
- **Graceful degradation** — run in a daemon-less Linux CI container, the script has *zero* notification backends (`terminal-notifier`/`osascript`/`afplay` all absent, `curl` push skipped without a topic). Backend-absence IS the CI condition, and it is identical to the real offline/sandbox path. Exit 0 there proves the script degrades cleanly rather than erroring the hook.

Run via the official `bats/bats` Docker image (mirrors `begin/tests/run.sh`), installing `jq` in the container so the script runs to completion. Wired into a path-filtered `.github/workflows/claude-notify-tests.yml` (`claude-notify/**`), matching `begin`'s CI.

*Alternatives considered:* no tests (handoff's initial lean) — rejected, it drops the one guard against the bug that actually happened; bats file but no CI — rejected as the odd middle (a test CI never runs rots, and the root README states CI is path-filtered per tool).

### Non-blocking is the keystone requirement

Every design choice derives from one guarantee: **the hook must never block Claude Code.** That is *why* `afplay` is backgrounded, *why* the ntfy `curl` is backgrounded and failure-swallowed, *why* the script exits 0 even when every backend fails, *why* `-sender` is banned, and *why* the smoke test wraps the run in `timeout`. Stating it as requirement #1 turns the `-sender` ban from a mystery line into a rule with a reason that survives future "cleanups".

### Install: clone + symlink, stable hook path

Same model as `begin`. Clone once, `chmod +x notify.sh`, `ln -sf …/claude-notify/notify.sh ~/.claude/hooks/notify.sh`. Because Claude Code's hooks call the fixed path `~/.claude/hooks/notify.sh`, symlinking that path into the repo is transparent — **no `settings.json` edit**. `git pull` updates every box.

## Risks / Trade-offs

- **Cutover replaces a live file with a symlink** → Mitigated: the committed content is verified byte-identical to the live file *before* the swap; rollback is replacing the symlink with the file (or re-copying from the repo). The two knob edits change defaults-preserving behavior only.
- **CI can't assert a banner actually appeared** → Accepted: CI proves non-blocking + exit-0 degradation (the failure modes that matter for a hook). Visual banner correctness is verified manually on macOS during acceptance.
- **`bats/bats` image lacks `jq`** → Mitigated: `run.sh` installs `jq` in the container (as `begin`'s installs `tmux`); otherwise `field()` returns empty and the test wouldn't exercise the real path.
- **`CLAUDE_NOTIFY_MUTE_WHILE` as a space-separated string** → Simple word-split loop over `pgrep -x` per name; documented format. Acceptable for a personal tool; no quoting-heavy names expected.
- **Secret leakage** → Mitigated: only `ntfy.env.example` is committed; the real `~/.claude/hooks/ntfy.env` lives outside the repo. Optional belt-and-suspenders `.gitignore` entry `claude-notify/ntfy.env`.

## Migration Plan

Net-new, additive. Clean-machine install:

```sh
git clone git@github.com:Dzhuneyt/toolkit.git ~/src/toolkit
chmod +x ~/src/toolkit/claude-notify/notify.sh
mkdir -p ~/.claude/hooks
ln -sf ~/src/toolkit/claude-notify/notify.sh ~/.claude/hooks/notify.sh
# optional phone push:
cp ~/src/toolkit/claude-notify/ntfy.env.example ~/.claude/hooks/ntfy.env
# then edit ~/.claude/hooks/ntfy.env → set NTFY_TOPIC to a random unguessable string
```

Cutover on the owner's Mac (already has the live file): confirm committed content matches the live file, then `ln -sf …/claude-notify/notify.sh ~/.claude/hooks/notify.sh`. Updates: `git pull`. Rollback: replace the symlink with a regular file.

## Open Questions

- ~~Keep `term_bundle` / Zoom check hardcoded, or parameterize?~~ **Resolved:** both lifted to env knobs with current values as defaults; DND stays commented.
- ~~Tests: none, bats-only, or bats + CI?~~ **Resolved:** bats smoke test + path-filtered CI (`begin` parity).
- Add `claude-notify/ntfy.env` to `.gitignore` as belt-and-suspenders, or rely on only committing the `.example`? Leaning: add the ignore line; finalize in implementation.
