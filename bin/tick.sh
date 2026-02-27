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

# Current time or Override
if [[ -n "${1:-}" ]]; then
  NOW="$1"
  echo "DEBUG: Manual time override: $NOW" >&2
else
  NOW="$(date +%H:%M)"
fi

# Find matches in schedule.txt
if [[ ! -f "$ROUTINE_SCHEDULE" ]]; then
    echo "Error: Schedule file not found at $ROUTINE_SCHEDULE" >&2
    exit 1
fi

while read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  TIME="${line%% *}"
  FILE="${line#* }"
  
  if [[ "$TIME" == "$NOW" ]]; then
    echo "Time matched: $NOW. Playing $FILE at volume ${DEFAULT_VOLUME:-0.8}"
    # Call the modern, mainstream chime script.
    "${BASE_DIR}/bin/smart-chime.sh" "$FILE" "${DEFAULT_VOLUME:-0.8}"
  fi
done < "$ROUTINE_SCHEDULE"
