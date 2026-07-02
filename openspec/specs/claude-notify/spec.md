# claude-notify Specification

## Purpose
TBD - created by archiving change add-claude-notify. Update Purpose after archive.
## Requirements
### Requirement: Never block Claude Code

The dispatcher SHALL return control to Claude Code promptly and MUST NOT block the hook for the duration of any notification action. All potentially slow operations (sound playback, phone push) SHALL be backgrounded, and the script SHALL exit 0 even when every notification backend is unavailable or fails. The dispatcher MUST NOT use any option or command known to block indefinitely (notably `terminal-notifier -sender`, which hangs on modern macOS).

#### Scenario: All backends absent

- **WHEN** the dispatcher runs on a host where `terminal-notifier`, `osascript`, `afplay`, and a reachable ntfy server are all absent
- **THEN** it returns promptly and exits 0 without erroring the hook

#### Scenario: Phone push failure is swallowed

- **WHEN** an ntfy topic is configured but the network is down or the server is unreachable
- **THEN** the push attempt is backgrounded and its failure does not block the hook, does not affect the desk notification, and does not change the exit code

#### Scenario: No blocking flags

- **WHEN** the dispatcher invokes `terminal-notifier`
- **THEN** it does not pass `-sender` (which blocks indefinitely), accepting the generic icon as the trade-off

### Requirement: Event dispatch with per-event sound and project-aware title

On a `Notification` or `Stop` event, the dispatcher SHALL read the hook JSON payload from stdin, play a system sound via `afplay`, and fire a desk notification titled `Claude Code [<project>]`, where `<project>` is the basename of `$CLAUDE_PROJECT_DIR`. The sound SHALL vary by event and, for `Notification`, by `notification_type`, so the event can be identified by ear alone.

#### Scenario: Permission prompt notification

- **WHEN** a `Notification` event arrives with `notification_type` of `permission_prompt`
- **THEN** the `Sosumi` sound plays and a banner is posted with the payload `message` as its body

#### Scenario: Stop event

- **WHEN** a `Stop` event arrives
- **THEN** the `Glass` sound plays and the banner body reads `Done`, or `Subagent done: <agent_type>` when the payload carries an `agent_type`

#### Scenario: Title from project directory

- **WHEN** `$CLAUDE_PROJECT_DIR` is set to a project path
- **THEN** the banner title is `Claude Code [<basename>]`; if the variable is absent the title falls back to `Claude Code [unknown]`

### Requirement: Graceful degradation across notification backends

The dispatcher SHALL prefer `terminal-notifier` for the desk banner (for click-to-focus and per-project coalescing) and SHALL fall back to `osascript` when `terminal-notifier` is not installed. The phone push SHALL be attempted only when an ntfy topic is configured.

#### Scenario: terminal-notifier absent

- **WHEN** `terminal-notifier` is not on `PATH`
- **THEN** the dispatcher posts the banner via `osascript` instead, without error

#### Scenario: Coalescing without silent re-alert

- **WHEN** `terminal-notifier` is used and a prior banner exists for the same project group
- **THEN** the dispatcher removes the prior banner before posting so the new event re-alerts rather than updating silently

#### Scenario: No ntfy topic configured

- **WHEN** no `NTFY_TOPIC` is set (no `ntfy.env`, or it lacks the topic)
- **THEN** the phone push is skipped entirely and desk notification and sound still fire

### Requirement: Secret handling for the ntfy topic

The ntfy topic is a shared secret. The repository SHALL contain only a placeholder template (`ntfy.env.example`) and MUST NOT contain the real topic. At runtime the dispatcher SHALL source the real configuration from a machine-local file outside the repository (`~/.claude/hooks/ntfy.env`).

#### Scenario: Only the example is committed

- **WHEN** the tool is committed to the repository
- **THEN** `ntfy.env.example` with a placeholder topic is present and no file containing the real topic is tracked

#### Scenario: Runtime config is machine-local

- **WHEN** the dispatcher needs the ntfy topic
- **THEN** it sources `~/.claude/hooks/ntfy.env` (if present) from outside the repository, never a committed file

### Requirement: Portability knobs for terminal and mute processes

The click-to-focus terminal bundle id and the set of "mute while running" process names SHALL be configurable via environment variables, each defaulting to the owner's current value so existing behavior is preserved when unset.

#### Scenario: Override the terminal bundle

- **WHEN** `CLAUDE_NOTIFY_TERM_BUNDLE` is set
- **THEN** the banner's click-to-focus target uses that bundle id; when unset it defaults to `com.cmuxterm.app`

#### Scenario: Override the mute process list

- **WHEN** `CLAUDE_NOTIFY_MUTE_WHILE` is set to a space-separated list of process names
- **THEN** those processes are checked for the mute behavior; when unset it defaults to `CptHost`

### Requirement: Suppress notifications while a muted process runs

When any process named in the mute list is running, the dispatcher SHALL suppress all output (no sound, no banner, no push) and exit 0.

#### Scenario: Muting process is active

- **WHEN** a process in the mute list (default `CptHost`, Zoom's meeting helper) is running
- **THEN** the dispatcher emits nothing and exits 0

### Requirement: Installation via stable hook path and symlink

A machine SHALL adopt the tool by cloning the repository and symlinking the entrypoint to the fixed hook path `~/.claude/hooks/notify.sh`. Because Claude Code invokes that fixed path, no change to `~/.claude/settings.json` SHALL be required. The repository is the single source of truth; `git pull` updates every box.

#### Scenario: Symlink into the repo

- **WHEN** `~/.claude/hooks/notify.sh` is a symlink pointing into the cloned `claude-notify/notify.sh`
- **THEN** Claude Code's existing hook configuration fires the repo's script unchanged, with no `settings.json` edit

#### Scenario: Update via git pull

- **WHEN** the clone is updated with `git pull`
- **THEN** every box whose hook path symlinks into the clone runs the updated script with no re-copy

### Requirement: Regression-tested non-blocking behavior

The tool SHALL include an automated test that pipes a representative payload through the dispatcher under a time guard and asserts prompt exit 0, and this test SHALL run in CI. Executed in a container without any notification backend, the test simultaneously guards the no-hang guarantee and the all-backends-absent degradation path.

#### Scenario: Smoke test guards against hangs

- **WHEN** the test pipes a payload through the dispatcher wrapped in `timeout`
- **THEN** it asserts the script exits 0 within the time limit (a hang would surface as a non-zero timeout exit)

#### Scenario: Test runs in CI without backends

- **WHEN** the path-filtered CI workflow runs the suite in a daemon-less Linux container
- **THEN** the dispatcher runs to completion and exits 0 despite having no `terminal-notifier`/`osascript`/`afplay`/ntfy backend available

