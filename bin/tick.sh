#!/usr/bin/env bash
set -euo pipefail

# Load config
CONF="/home/onur/soundctl/config/soundctl.conf"
# shellcheck disable=SC1090
source "$CONF"

TODAY="$(date +%Y%m%d)"
# Removed state tracking as requested

# Current time or Override
if [[ -n "${1:-}" ]]; then
  NOW="$1"
  echo "DEBUG: Manual time override: $NOW" >&2
else
  NOW="$(date +%H:%M)"
fi

# Find matches in schedule
# Format: HH:MM filename.mp3
MATCHES=()
while read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  TIME="${line%% *}"
  FILE="${line#* }"
  
  if [[ "$TIME" == "$NOW" ]]; then
    MATCHES+=("$FILE")
  fi
done < "$ROUTINE_SCHEDULE"

if [[ ${#MATCHES[@]} -gt 0 ]]; then
  for file in "${MATCHES[@]}"; do
    # soundctl.sh handles logging now
    /home/onur/soundctl/bin/soundctl.sh play "$file"
  done
fi
