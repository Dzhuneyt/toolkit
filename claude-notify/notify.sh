#!/usr/bin/env bash
# Claude Code notification dispatcher.
# Reads hook JSON payload from stdin, fires native macOS notification + sound.
# Usage: notify.sh <Notification|Stop>

set -u

# Suppress everything while any "mute" process runs (default: Zoom's CptHost
# helper, present during an active meeting). Space-separated process names;
# override with CLAUDE_NOTIFY_MUTE_WHILE. Unquoted expansion is intentional —
# the list is word-split into names.
mute_while="${CLAUDE_NOTIFY_MUTE_WHILE:-CptHost}"
for proc in $mute_while; do
  if pgrep -x "$proc" > /dev/null; then
    exit 0
  fi
done

# To check macOS Focus Mode (Do Not Disturb), uncomment the lines below:
# DND_COUNT=$(jq '.data[0].storeAssertionRecords | length' ~/Library/DoNotDisturb/DB/Assertions.json 2>/dev/null || echo 0)
# if [ "$DND_COUNT" -gt 0 ]; then
#   exit 0
# fi

event=${1:-unknown}
payload=$(cat)

field() { jq -r "${1} // \"\"" <<<"$payload" 2>/dev/null; }

dir=$(basename "${CLAUDE_PROJECT_DIR:-unknown}")

case "$event" in
  Notification)
    body=$(field .message)
    [ -z "$body" ] && body="Needs attention"
    # Sound per notification_type so the ear alone tells you why Claude pinged
    case "$(field .notification_type)" in
      permission_prompt)  sound="Sosumi" ;;
      idle_prompt)        sound="Submarine" ;;
      auth_success)       sound="Tink" ;;
      elicitation_dialog) sound="Purr" ;;
      *)                  sound="Submarine" ;;
    esac
    ;;
  Stop)
    agent=$(field .agent_type)
    body=${agent:+Subagent done: $agent}
    body=${body:-Done}
    sound="Glass"
    ;;
  *)
    body="Event: $event"
    sound="Pop"
    ;;
esac

afplay "/System/Library/Sounds/$sound.aiff" &

# Desk notification. terminal-notifier adds click-to-focus (clicking jumps to the
# cmux window that's waiting) and -group coalescing (repeat pings replace rather
# than pile up). Falls back to osascript if terminal-notifier isn't installed, so
# uninstalling the brew package degrades gracefully instead of going silent.
term_bundle="${CLAUDE_NOTIFY_TERM_BUNDLE:-com.cmuxterm.app}"   # cmux (Ghostty fork) — app brought to front on click; override per box
if command -v terminal-notifier >/dev/null 2>&1; then
  # Clear any prior banner for this project first. Re-posting the same -group
  # only updates the existing entry *silently* (no re-alert) — fatal for a
  # needs-input ping. Removing then posting keeps "one banner per project" while
  # still alerting every time.
  terminal-notifier -remove "claude-$dir" >/dev/null 2>&1
  terminal-notifier \
    -title "Claude Code [$dir]" \
    -message "$body" \
    -activate "$term_bundle" \
    -group "claude-$dir" >/dev/null 2>&1
else
  # Env-var handoff sidesteps all shell/AppleScript quoting pitfalls in $body
  N_TITLE="Claude Code [$dir]" N_BODY="$body" osascript <<'APPLESCRIPT'
display notification (system attribute "N_BODY") with title (system attribute "N_TITLE")
APPLESCRIPT
fi

# Phone push via ntfy.sh — optional, best-effort. Skipped entirely if no topic
# is configured, and backgrounded + failure-swallowed so it never blocks the
# hook or breaks the desk notification above if the network is down.
ntfy_config="$HOME/.claude/hooks/ntfy.env"
[ -f "$ntfy_config" ] && . "$ntfy_config"
if [ -n "${NTFY_TOPIC:-}" ]; then
  # Priority + tag per event so the phone alert reads at a glance
  case "$event" in
    Notification) ntfy_priority="high";    ntfy_tags="bell" ;;
    Stop)         ntfy_priority="default"; ntfy_tags="white_check_mark" ;;
    *)            ntfy_priority="default"; ntfy_tags="robot" ;;
  esac
  curl -fsS \
    -H "Title: Claude Code [$dir]" \
    -H "Priority: $ntfy_priority" \
    -H "Tags: $ntfy_tags" \
    -d "$body" \
    "${NTFY_SERVER:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null 2>&1 &
fi
