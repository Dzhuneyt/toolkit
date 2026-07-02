## 1. Component scaffolding (repo containment)

- [x] 1.1 Create the self-contained `claude-notify/` subdirectory at the repo root (no source/test files at the repo root)
- [x] 1.2 Create `claude-notify/tests/` directory

## 2. Dispatcher adoption + portability knobs

- [x] 2.1 Copy the live `~/.claude/hooks/notify.sh` into `claude-notify/notify.sh` verbatim; `chmod +x`
- [x] 2.2 Apply knob 1: `term_bundle="${CLAUDE_NOTIFY_TERM_BUNDLE:-com.cmuxterm.app}"`
- [x] 2.3 Apply knob 2: replace `pgrep -x "CptHost"` with a loop over `mute_while="${CLAUDE_NOTIFY_MUTE_WHILE:-CptHost}"` (space-separated names); suppress + exit 0 if any is running
- [x] 2.4 Confirm the commented-out Do-Not-Disturb block is preserved as-is (not promoted to a knob)
- [x] 2.5 Verify no other lines changed vs. the live file (diff; only 2.2/2.3 should differ) — confirmed: everything from `event=` on is byte-identical bar the term_bundle knob
- [x] 2.6 Preserve bash 3.2 / macOS compatibility (no bash-4-only features introduced by the knob edits) — `bash -n` clean; only a `for` loop added

## 3. Config template + secret boundary

- [x] 3.1 Create `claude-notify/ntfy.env.example` with a placeholder topic only (no real value), documenting `NTFY_TOPIC` and optional `NTFY_SERVER`
- [x] 3.2 (Open question) Add `claude-notify/ntfy.env` to `.gitignore` as belt-and-suspenders
- [x] 3.3 Confirm the real `~/.claude/hooks/ntfy.env` is never staged (lives outside the repo; unstageable)

## 4. Documentation

- [x] 4.1 Write `claude-notify/README.md` mirroring `begin/README.md` structure (What it does / Install clean machine / Dependencies table / Config knobs / Layout)
- [x] 4.2 Document the three output channels (desk banner + osascript fallback, per-event sound, optional best-effort phone push) and the non-blocking guarantee
- [x] 4.3 Document config knobs: `NTFY_TOPIC`, `NTFY_SERVER`, `CLAUDE_NOTIFY_TERM_BUNDLE`, `CLAUDE_NOTIFY_MUTE_WHILE`
- [x] 4.4 Merge the still-valid gotchas from the superseded `~/.claude/hooks/README.md` (afplay/osascript sound bug; Mac Roman title mojibake — narrowed to the osascript fallback; afplay must be backgrounded; `$CLAUDE_PROJECT_DIR` scope; sandbox silent-success)
- [x] 4.5 Add the three gotchas earned this round: `-sender` hangs (exit 124); `-appIcon` ignored for the main icon; `-group` without a preceding `-remove` updates silently
- [x] 4.6 Carry over the sound-map table and a Customizing section from the old README
- [x] 4.7 Note the macOS/Zoom-specific nature of the mute + (commented) DND behavior
- [x] 4.8 Add a `claude-notify/` row to the root `README.md` Tools table

## 5. Test + CI (begin parity)

- [x] 5.1 Write `claude-notify/tests/notify.bats`: pipe a `permission_prompt` payload through the script under `timeout`, assert exit 0 (no hang) with `CLAUDE_PROJECT_DIR` set
- [x] 5.2 Add a `Stop`-event case asserting exit 0 (+ a missing-`CLAUDE_PROJECT_DIR` case)
- [x] 5.3 Add `claude-notify/tests/run.sh` running the suite via the official `bats/bats` Docker image, installing `jq` in the container (mirror `begin/tests/run.sh`)
- [x] 5.4 Add `.github/workflows/claude-notify-tests.yml`, path-filtered to `claude-notify/**`, ubuntu-latest, running `bash claude-notify/tests/run.sh`; verified `run.sh` propagates the bats exit code (ran green locally, 3/3, exit 0)

## 6. Cutover + verification

- [x] 6.1 Confirm committed `claude-notify/notify.sh` (minus the 2 knobs) matches the live file before swapping
- [x] 6.2 Cutover: `ln -sf …/toolkit/claude-notify/notify.sh ~/.claude/hooks/notify.sh`; confirmed `readlink` resolves into the repo
- [x] 6.3 No `~/.claude/settings.json` edit (hook path unchanged)
- [x] 6.4 Verify non-hang: piped a payload with `timeout 8`, `exit=0` (direct path + via symlink)
- [x] 6.5 Manual acceptance (macOS): a desk banner titled `Claude Code [demo]` fired — visually confirm click-to-focus
- [x] 6.6 Manual acceptance: per-event sounds fired (Sosumi permission_prompt, Glass on Stop)
- [x] 6.7 Manual acceptance: real `~/.claude/hooks/ntfy.env` present → phone push path executed during verify (confirm receipt on device)
- [x] 6.8 Manual acceptance: `CLAUDE_NOTIFY_MUTE_WHILE=WindowServer` → suppressed, exit 0
- [x] 6.9 CI green on the path-filtered workflow (PR #2, bats 3/3 pass)
