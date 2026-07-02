# claude-notify

Native macOS notifications for [Claude Code](https://code.claude.com) — a desk
banner, a per-event sound, and an optional phone push — fired whenever a session
needs input or finishes. One bash dispatcher wired to Claude Code's `Notification`
and `Stop` hooks. The same script is meant to live on every box (clone + symlink;
`git pull` to update).

## What it does

`notify.sh` reads the hook's JSON payload from stdin and fans out to three
channels. **The overriding rule: it must never block Claude Code** — every slow
step is backgrounded and the script exits 0 even when nothing can actually
notify, so a missing tool or a dead network degrades silently instead of hanging
the hook.

1. **Desk notification** via `terminal-notifier` — click-to-focus (clicking the
   banner brings the waiting terminal to the front) and `-group` coalescing (one
   banner per project; repeat pings replace rather than pile up). Falls back to
   `osascript` when `terminal-notifier` isn't installed, so uninstalling the brew
   package degrades gracefully instead of going silent.
2. **Sound** via `afplay` — a distinct macOS system sound per event /
   `notification_type`, so the ear alone tells you why Claude pinged.
3. **Phone push** via [ntfy.sh](https://ntfy.sh) — optional, best-effort.
   Backgrounded and failure-swallowed so it never blocks the hook or breaks the
   desk banner if you're offline. Skipped entirely when no `NTFY_TOPIC` is set.

Suppressed entirely while a "mute" process is running (default: Zoom's
`CptHost`, present during a meeting) — no sound, no banner, no push.

## Install (clean machine)

```sh
# 1. Clone
git clone git@github.com:Dzhuneyt/toolkit.git ~/src/toolkit

# 2. Make the entrypoint executable
chmod +x ~/src/toolkit/claude-notify/notify.sh

# 3. Symlink it to the fixed hook path Claude Code calls
mkdir -p ~/.claude/hooks
ln -sf ~/src/toolkit/claude-notify/notify.sh ~/.claude/hooks/notify.sh

# 4. (optional) phone push — copy the example and set a private topic
cp ~/src/toolkit/claude-notify/ntfy.env.example ~/.claude/hooks/ntfy.env
# then edit ~/.claude/hooks/ntfy.env → set NTFY_TOPIC to a random unguessable string
```

Then wire the hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "/Users/<you>/.claude/hooks/notify.sh Notification" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "/Users/<you>/.claude/hooks/notify.sh Stop" }] }
    ]
  }
}
```

The hook calls the fixed path `~/.claude/hooks/notify.sh`, which is now a symlink
into the clone — so **updating every box later is just `git pull`**, no
`settings.json` edit and nothing to re-copy. The hook event name
(`Notification` / `Stop`) must be passed as `$1`.

## Dependencies

| Tool               | Required | Used for                                                        |
|--------------------|----------|-----------------------------------------------------------------|
| `bash`             | yes      | the script (kept bash-3.2 / macOS compatible)                   |
| `jq`               | yes      | parses the hook JSON payload from stdin                         |
| `afplay`           | yes\*    | plays the per-event sound (macOS built-in)                      |
| `pgrep`            | yes\*    | the mute-while-running check (macOS built-in)                   |
| `osascript`        | yes\*    | fallback desk notification (macOS built-in)                     |
| `terminal-notifier`| no       | click-to-focus + coalescing banner; falls back to `osascript`   |
| `curl`             | no       | only for the ntfy phone push                                    |
| `ntfy` phone app   | no       | to receive the pushes on your device                            |

\* macOS built-ins. On a non-macOS host (e.g. a CI runner) they're absent — the
script still runs to completion and exits 0 (that's the graceful-degradation
path, exercised by the test).

## Config knobs

| Env var                     | Default              | What                                                                 |
|-----------------------------|----------------------|---------------------------------------------------------------------|
| `NTFY_TOPIC`                | (unset → push off)   | ntfy topic to publish to. Set in `~/.claude/hooks/ntfy.env`.        |
| `NTFY_SERVER`               | `https://ntfy.sh`    | ntfy server, for self-hosting. Set in `ntfy.env`.                   |
| `CLAUDE_NOTIFY_TERM_BUNDLE` | `com.cmuxterm.app`   | bundle id brought to front on banner click. Set per box.           |
| `CLAUDE_NOTIFY_MUTE_WHILE`  | `CptHost`            | space-separated process names; any running → suppress + exit 0.     |

`CLAUDE_NOTIFY_TERM_BUNDLE` and `CLAUDE_NOTIFY_MUTE_WHILE` default to the author's
machine (cmux terminal, Zoom) — override them via the environment on other boxes.
A commented-out **Do-Not-Disturb** check also lives in the script as an example;
it reads an undocumented internal macOS DB, so it's left commented rather than
promoted to a supported knob.

## Sound map

| Event          | `notification_type`   | Sound     |
|----------------|-----------------------|-----------|
| `Notification` | `permission_prompt`   | Sosumi    |
| `Notification` | `idle_prompt`         | Submarine |
| `Notification` | `auth_success`        | Tink      |
| `Notification` | `elicitation_dialog`  | Purr      |
| `Notification` | (other/unknown)       | Submarine |
| `Stop`         | main thread           | Glass     |
| `Stop`         | inside subagent       | Glass (body reads `Subagent done: <agent_type>`) |

All sounds resolve to `/System/Library/Sounds/<Name>.aiff`. Run
`ls /System/Library/Sounds/` to see the available names; swap any entry in the
script's `case` blocks. Custom paths work too — `afplay` accepts `.wav`, `.aiff`,
`.mp3`, `.m4a`.

## Payload fields consumed

Claude Code hands each hook a JSON blob on stdin. This script reads:

- `message` — the human-readable reason Claude is notifying (used as the body)
- `notification_type` — `permission_prompt` / `idle_prompt` / `auth_success` / `elicitation_dialog`
- `agent_type` — present when `Stop` fires inside a subagent

It also reads `$CLAUDE_PROJECT_DIR` (set by Claude Code for all hooks) to build
the title: `basename` of that path appears in brackets, e.g. `Claude Code [toolkit]`.

## Gotchas (read before "improving" the script)

Every non-obvious line traces to a real failure hit in testing. Don't undo these:

- **`terminal-notifier -sender` HANGS** on modern macOS — blocks forever (exit
  124), which would freeze Claude Code on every hook event. `-sender` is the only
  flag that swaps the notification's icon, so the icon stays the generic
  terminal-notifier one — accepted trade-off. **Never re-add `-sender`.**
- **`-appIcon` is ignored** by modern macOS for the main icon. Don't re-add it to
  chase the icon either.
- **`-group` without a preceding `-remove` re-alerts silently.** Re-posting the
  same `-group` only *updates* the existing banner with no new alert — fatal for
  a needs-input ping. The script does `-remove` then post, keeping "one banner
  per project" while still alerting every time.
- **`osascript`'s `sound name "..."` clause is broken** on recent macOS — the
  notification fires but no sound plays. That's *why* sound is a separate `afplay`
  call. Don't re-add `sound name` to the AppleScript; it won't help.
- **`afplay` must be backgrounded** (`afplay … &`) or the hook blocks for the full
  length of the sound. Already backgrounded.
- **Non-ASCII in the title mojibakes on the `osascript` fallback path.**
  AppleScript's `system attribute` returns Mac Roman, not UTF-8, so `—` renders as
  `,Äî`. `terminal-notifier` (the primary path) handles UTF-8 fine; the bug only
  bites when `terminal-notifier` is absent and `$dir` is non-ASCII. Non-ASCII in
  the *body* works via the env-var handoff — the bug is the title string literal.
- **`$CLAUDE_PROJECT_DIR` is the project root**, set per hook invocation — stable
  even when Claude `cd`s into subdirectories mid-session, not the shell's cwd.
- **Sandbox/container silent success.** If Claude Code runs somewhere without the
  host notification daemon, `osascript`/`terminal-notifier` succeed silently and
  nothing appears. Test with `osascript -e 'display notification "test"'` from the
  same shell.

The mute-while-running and (commented) Do-Not-Disturb checks are macOS/Zoom
specific — personal defaults, overridable via `CLAUDE_NOTIFY_MUTE_WHILE`.

## Testing without Claude Code

Pipe a fake payload:

```sh
echo '{"message":"Test","notification_type":"permission_prompt"}' \
  | CLAUDE_PROJECT_DIR=/tmp/my-project ./notify.sh Notification
```

You should hear Sosumi and see a banner titled `Claude Code [my-project]` with
body `Test`. The automated suite is a smoke test that guards the non-blocking
guarantee — it runs in Docker (no host install):

```sh
claude-notify/tests/run.sh
```

## Layout

```
claude-notify/
  notify.sh           # the dispatcher (Notification + Stop hooks)
  ntfy.env.example    # committed template; real topic lives in ~/.claude/hooks/ntfy.env
  tests/
    notify.bats       # smoke test: payload in → prompt exit 0 (no hang, degrades cleanly)
    run.sh            # runs the suite via the official bats/bats Docker image
  README.md
```
