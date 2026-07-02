## Why

A working Claude Code notification dispatcher currently lives only in machine-local `~/.claude/hooks/notify.sh` on one Mac. It fires desk banners, per-event sounds, and optional phone push whenever Claude Code needs attention or finishes — but it is not version-controlled, so it cannot be reproduced on another box and its hard-won portability fixes (a `terminal-notifier -sender` hang, macOS mojibake, an `afplay` blocking bug) are undocumented and one accidental edit from being lost. Adopting it into `toolkit/` as a self-contained `claude-notify` tool makes it reproducible on every box via the same clone + symlink model already used by `begin`, and captures the failure modes as rules with reasons.

## What Changes

- New `claude-notify/` tool: `notify.sh` dispatcher + `ntfy.env.example` template + `README.md`, fully self-contained under its own top-level directory.
- **Adopt, don't rewrite**: the dispatcher is byte-identical to the live, hardened `~/.claude/hooks/notify.sh` — except two portability edits below. The behavior that already works is preserved verbatim.
- **Portability knob — terminal bundle**: the click-to-focus target (`com.cmuxterm.app`, the owner's terminal) becomes `${CLAUDE_NOTIFY_TERM_BUNDLE:-com.cmuxterm.app}` so other boxes set one env var instead of editing the committed script; degrades to a harmless no-op elsewhere.
- **Portability knob — mute-while-running**: the hardcoded Zoom-mute process check (`pgrep -x CptHost`) becomes `${CLAUDE_NOTIFY_MUTE_WHILE:-CptHost}` (space-separated process names) so the committed artifact is not silently opinionated about the owner's Zoom. The commented-out Do-Not-Disturb block stays commented (it reads a fragile internal macOS DB; kept as an example, not promoted to a knob).
- **Secret boundary**: only `ntfy.env.example` (placeholder topic) is committed. The real topic stays in machine-local `~/.claude/hooks/ntfy.env`, outside the repo, never staged.
- **Documentation carries the gotchas**: the new README merges the still-valid gotchas from the superseded `~/.claude/hooks/README.md` (afplay/osascript sound bug, Mac Roman title mojibake — now narrowed to the osascript fallback path, afplay must be backgrounded, `$CLAUDE_PROJECT_DIR` scope, sandbox silent-success) and adds the three earned this round: `-sender` hangs (exit 124), `-appIcon` is ignored, and `-group` without a preceding `-remove` updates silently (fatal for a needs-input ping).
- **Smoke test + CI (`begin` parity)**: one bats test pipes a payload, guards with `timeout`, and asserts prompt `exit 0` — catching any reintroduced hang and simultaneously proving graceful degradation (a daemon-less Linux CI runner has zero notification backends, which is exactly the offline/sandbox condition). Wired into a path-filtered `.github/workflows/` job like `begin`'s.
- **Cutover**: replace the live regular file with a symlink into the repo so the clone becomes the source of truth. Hook paths in `~/.claude/settings.json` are unchanged — they point at the stable `~/.claude/hooks/notify.sh` path, which becomes the symlink.

## Capabilities

### New Capabilities
- `claude-notify`: A non-blocking Claude Code hook dispatcher that emits a desk notification, a per-event sound, and an optional best-effort phone push on `Notification` and `Stop` events, degrading gracefully when any backend is absent.

### Modified Capabilities
<!-- None — net-new standalone tool. -->

## Impact

- New files under `claude-notify/`: `notify.sh`, `ntfy.env.example`, `README.md`, `tests/*.bats` (+ `tests/run.sh`), and `.github/workflows/claude-notify-tests.yml`. New row in the root `README.md` Tools table.
- Runtime dependencies: `bash` (3.2/macOS-compatible), `jq` (required — parses the hook JSON payload), `afplay`/`osascript`/`pgrep` (macOS built-ins). Optional: `terminal-notifier` (click-to-focus + coalescing; falls back to osascript), `curl` (only for ntfy phone push), the `ntfy` phone app to receive pushes.
- Dev/test dependency: `bats-core`, run via the official `bats/bats` Docker image (mirrors `begin`), installing `jq` in the container so the script runs to completion.
- Machine change on the owner's Mac: `~/.claude/hooks/notify.sh` changes from a regular file to a symlink into the clone. No `settings.json` edit. Rollback: replace the symlink with the file, or re-copy from the repo.
- Out of scope: any change to Claude Code's hook wiring, additional notification channels (Slack/Discord/etc.), and distribution/sync of the clone across boxes (handled by the clone + `git pull` model, same as `begin`).
