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
    # Sound + phone-title icon per notification_type so the ear (and phone glance)
    # alone tell you why Claude pinged
    case "$(field .notification_type)" in
      permission_prompt)  sound="Sosumi";   icon="🔐" ;;
      idle_prompt)        sound="Submarine"; icon="⏳" ;;
      auth_success)       sound="Tink";     icon="🔓" ;;
      elicitation_dialog) sound="Purr";     icon="❓" ;;
      *)                  sound="Submarine"; icon="🔔" ;;
    esac
    ;;
  Stop)
    agent=$(field .agent_type)
    body=${agent:+Subagent done: $agent}
    body=${body:-Done}
    sound="Glass"
    icon="✅"
    # Phone body carries the actual final turn text (desk banner keeps the short
    # "Done"). Trimmed to keep the push readable; rendered as Markdown below.
    ntfy_body=$(field .last_assistant_message | head -c 300)
    ntfy_markdown="yes"
    # max_tokens means Claude was cut off mid-thought — flag it so a truncated
    # answer isn't mistaken for a clean finish
    [ "$(field .stop_reason)" = "max_tokens" ] && ntfy_body="⚠️ hit token cap — $ntfy_body"
    ;;
  *)
    body="Event: $event"
    sound="Pop"
    ;;
esac

# Phone-only enrichments fall back to the desk values when a branch didn't set them
icon="${icon:-🤖}"
ntfy_body="${ntfy_body:-$body}"

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

# Skip the phone push (desk notification above still fires) when the desk
# itself already puts the alert in front of you: machine used within the
# idle threshold, or inside the configured quiet-hours window. Either gate
# can be disabled by setting its var to 0 in ntfy.env.
ntfy_skip_reason=""

if [ "${NTFY_IDLE_GATE_ENABLED:-1}" != "0" ]; then
  idle_threshold="${NTFY_IDLE_THRESHOLD_SECONDS:-180}"
  idle_ns=$(ioreg -c IOHIDSystem | awk -F'= ' '/HIDIdleTime/ {print $2; exit}')
  if [ -n "$idle_ns" ]; then
    idle_seconds=$(( idle_ns / 1000000000 ))
    if [ "$idle_seconds" -lt "$idle_threshold" ]; then
      ntfy_skip_reason="active desk (idle ${idle_seconds}s < ${idle_threshold}s)"
    fi
  fi
fi

if [ -z "$ntfy_skip_reason" ] && [ "${NTFY_QUIET_HOURS_ENABLED:-1}" != "0" ]; then
  quiet_start="${NTFY_QUIET_HOURS_START:-22}"
  quiet_end="${NTFY_QUIET_HOURS_END:-8}"
  hour=$((10#$(date +%H)))
  # Window may wrap past midnight (e.g. 22 -> 8), so the in-range test differs
  # depending on whether start comes before or after end on the 24h clock.
  if [ "$quiet_start" -lt "$quiet_end" ]; then
    in_quiet_hours=$([ "$hour" -ge "$quiet_start" ] && [ "$hour" -lt "$quiet_end" ] && echo 1)
  else
    in_quiet_hours=$([ "$hour" -ge "$quiet_start" ] || [ "$hour" -lt "$quiet_end" ] && echo 1)
  fi
  [ -n "$in_quiet_hours" ] && ntfy_skip_reason="quiet hours (${quiet_start}:00-${quiet_end}:00)"
fi

if [ -n "${NTFY_TOPIC:-}" ] && [ -n "$ntfy_skip_reason" ]; then
  : # phone push suppressed — see ntfy_skip_reason; desk notification already fired above
elif [ -n "${NTFY_TOPIC:-}" ]; then
  # Priority + tag per event so the phone alert reads at a glance
  case "$event" in
    Notification) ntfy_priority="high";    ntfy_tags="bell" ;;
    Stop)         ntfy_priority="default"; ntfy_tags="white_check_mark" ;;
    *)            ntfy_priority="default"; ntfy_tags="robot" ;;
  esac
  # Tap-to-open: resolve the project's GitHub remote (SSH or HTTPS) to a web URL
  # so the phone notification deep-links to the repo. Empty Click header = no-op.
  ntfy_click=$(git -C "${CLAUDE_PROJECT_DIR:-.}" remote get-url origin 2>/dev/null \
    | sed 's#git@github.com:#https://github.com/#; s#\.git$##')
  curl -fsS \
    -H "Title: $icon Claude Code [$dir]" \
    -H "Priority: $ntfy_priority" \
    -H "Tags: $ntfy_tags" \
    -H "Markdown: ${ntfy_markdown:-no}" \
    -H "Click: $ntfy_click" \
    -d "$ntfy_body" \
    "${NTFY_SERVER:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null 2>&1 &
fi
