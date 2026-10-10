#!/usr/bin/env bash
set -euo pipefail

# This script is called by cron every minute (* * * * *).
# It checks the schedule and plays the sound if the time matches.

# --- Setup & Configuration ---
CONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)/soundctl.conf"
if [[ -f "$CONF" ]]; then source "$CONF"; else echo "Error: Config not found" >&2; exit 1; fi

# Check if bells are disabled (HA-managed field)
if [[ "${BELLS_ENABLED:-off}" != "on" ]]; then
  # Log that we are skipping because it's disabled, then exit.
  exit 0
fi

# Current date/time or Override
TODAY="$(date +%F)"
if [[ -n "${1:-}" ]]; then
  if [[ "$1" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    NOW="$1"
    echo "DEBUG: Manual time override: $NOW" >&2
  elif [[ "$1" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
    TODAY="${BASH_REMATCH[1]}"
    NOW="${BASH_REMATCH[2]}"
    echo "DEBUG: Manual date/time override: $TODAY $NOW" >&2
  else
    echo "Error: Override must be 'HH:MM' or 'YYYY-MM-DD HH:MM'" >&2
    exit 1
  fi
else
  NOW="$(date +%H:%M)"
fi

# Find matches in schedule.txt
if [[ ! -f "$ROUTINE_SCHEDULE" ]]; then
    echo "Error: Schedule file not found at $ROUTINE_SCHEDULE" >&2
    exit 1
fi

while read -r line; do
  [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue

  SCHEDULE_DATE=""
  SCHEDULE_TIME=""
  FILE=""
  LINE_VOLUME="${DEFAULT_VOLUME:-0.8}"

  if [[ "$line" =~ ^[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2})[[:space:]]+(.+)$ ]]; then
    SCHEDULE_DATE="${BASH_REMATCH[1]}"
    SCHEDULE_TIME="${BASH_REMATCH[2]}"
    FILE="${BASH_REMATCH[3]}"
  elif [[ "$line" =~ ^[[:space:]]*([0-9]{2}:[0-9]{2})[[:space:]]+(.+)$ ]]; then
    SCHEDULE_TIME="${BASH_REMATCH[1]}"
    FILE="${BASH_REMATCH[2]}"
  else
    echo "Warning: Invalid schedule line ignored: $line" >&2
    continue
  fi

  # Optional per-line volume override at the end of line (example: "... file.mp3 0.7")
  if [[ "$FILE" =~ ^(.+)[[:space:]]+([0-9]*\.?[0-9]+)$ ]]; then
    FILE="${BASH_REMATCH[1]}"
    LINE_VOLUME="${BASH_REMATCH[2]}"
  fi

  if [[ "$SCHEDULE_TIME" == "$NOW" ]] && [[ -z "$SCHEDULE_DATE" || "$SCHEDULE_DATE" == "$TODAY" ]]; then
    echo "Time matched: $NOW. Playing $FILE at volume ${LINE_VOLUME}"
    # Call the modern, mainstream chime script.
    "${BASE_DIR}/bin/smart-chime.sh" "$FILE" "${LINE_VOLUME}"
  fi
done < "$ROUTINE_SCHEDULE"
