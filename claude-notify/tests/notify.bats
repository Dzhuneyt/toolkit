#!/usr/bin/env bats
#
# Smoke test for the claude-notify dispatcher.
#
# The point is the ONE guarantee that matters for a hook: it must never block
# Claude Code. Piped a payload, the script must return promptly and exit 0 even
# with zero notification backends available — which is exactly this daemon-less
# container (no terminal-notifier / osascript / afplay, no ntfy topic). So the
# same run guards two things at once:
#   - no-hang: a reintroduced blocking flag (e.g. terminal-notifier -sender)
#     would trip `timeout` and surface as exit 124 != 0
#   - graceful degradation: exit 0 with no backends == the real offline/sandbox
#     path, proving the script degrades instead of erroring the hook

NOTIFY="${BATS_TEST_DIRNAME}/../notify.sh"

@test "Notification event returns promptly and exits 0" {
  run env CLAUDE_PROJECT_DIR=/tmp/demo timeout 8 bash "$NOTIFY" Notification <<<'{"message":"hi","notification_type":"permission_prompt"}'
  [ "$status" -eq 0 ]
}

@test "Stop event returns promptly and exits 0" {
  run env CLAUDE_PROJECT_DIR=/tmp/demo timeout 8 bash "$NOTIFY" Stop <<<'{"agent_type":"Explore"}'
  [ "$status" -eq 0 ]
}

@test "missing CLAUDE_PROJECT_DIR still exits 0" {
  run timeout 8 bash "$NOTIFY" Notification <<<'{"message":"hi"}'
  [ "$status" -eq 0 ]
}
