#!/usr/bin/env bash
set -euo pipefail

# Load Config
CONF="/home/onur/soundctl/config/soundctl.conf"
# shellcheck disable=SC1090
source "$CONF"

# --- Helpers ---

check_deps() {
  for cmd in curl "$AMIXER" "$PLAYER"; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing dependency: $cmd" >&2; exit 1; }
  done
}

# Fetch state from Home Assistant
ha_get() {
  local entity="$1"
  local token
  local token
  if [[ ! -f "$HA_TOKEN_FILE" ]]; then
      # No token file -> Assume optional/manual mode
      return 1
  fi
  token="$(cat "$HA_TOKEN_FILE")"
  
  # Simple grep/python parse to avoid jq dependency if missing
  local json
  json="$(curl -fsS --max-time 2 \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    "${HA_URL}/api/states/${entity}" 2>/dev/null || true)"
    
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r '.state' 2>/dev/null
  else
    # Python fallback
    echo "$json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('state',''))" 2>/dev/null || true
  fi
}

# Get current ALSA volume percentage
get_alsa_vol() {
  "$AMIXER" get "$ALSA_CONTROL" | grep -oP '\[\d+%\]' | head -1 | tr -d '[%]' || echo "50"
}

# Set ALSA volume
set_alsa_vol() {
  local val="$1"
  "$AMIXER" -q set "$ALSA_CONTROL" "${val}%"
}

# Get MP3 duration (approximate or precise)
get_duration() {
  local file="$1"
  if command -v ffprobe >/dev/null 2>&1; then
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | cut -d. -f1
  elif command -v mp3info >/dev/null 2>&1; then
    mp3info -p "%S" "$file" 2>/dev/null
  else
    # Fallback to python
    python3 -c "import sys; print(15)" # Default fallback if no tools
  fi
}

play() {
  local filename="$1"
  local filepath="${SOUNDS_DIR}/${filename}"

  if [[ ! -f "$filepath" ]]; then
    echo "File not found: $filepath" >&2
    exit 1
  fi

  # 1. Check if Enabled
  local state
  if ! state="$(ha_get "$ENTITY_ENABLED")"; then
    log "HA unavailable/disabled. Defaulting to ENABLED."
    state="on"
  fi

  if [[ "$state" != "on" ]]; then
    echo "Bells disabled (state: $state). Exiting."
    exit 0
  fi

  # 2. Get Current Volume (to restore later)
  local current_vol
  current_vol="$(get_alsa_vol)"

  # 3. Duck Volume (Default 30)
  set_alsa_vol "$DUCK_VOL"

  # 4. Get Target Volume from HA
  local target_vol_raw
  if ! target_vol_raw="$(ha_get "$ENTITY_VOL")"; then
     log "HA volume unavailable. Defaulting to 50%."
     target_vol_raw="50"
  fi

  # Validate/Clamp Target Volume
  local target_vol
  if [[ "$target_vol_raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    target_vol="${target_vol_raw%.*}" # int cast
  else
    target_vol=15 # Default safety
  fi
  
  # Calculate mpg123 scale factor (32768 = 100%)
  # Formula: 32768 * (vol / 100)
  local scale_factor
  scale_factor=$(( 32768 * target_vol / 100 ))

  # Warmup (prevent cutoff)
  sleep 1.5

  # 5. Play Audio with Scale Factor
  local dur
  dur="$(get_duration "$filepath")"
  [[ -z "$dur" ]] && dur=15
  local timeout_sec=$((dur + 5))

  "$PLAYER" $PLAYER_ARGS -f "$scale_factor" "$filepath" &
  local pid=$!

  # Wait for playback
  wait "$pid"

  # 6. Restore Volume
  set_alsa_vol "$current_vol"
}

# --- Main ---

command="${1:-}"
arg="${2:-}"


mkdir -p "$LOG_DIR"

log() {
  local msg="$1"
  local d
  d="$(date +'%Y-%m-%d %H:%M:%S')"
  local logfile="${LOG_DIR}/soundctl_$(date +%Y-%m-%d).log"
  echo "[$d] $msg" >> "$logfile"
}

check_deps

case "$command" in
  play)
    [[ -z "$arg" ]] && { echo "Usage: soundctl.sh play <filename>"; exit 1; }
    log "PLAY REQUEST: $arg"
    play "$arg"
    ;;
  *)
    echo "Usage: soundctl.sh play <filename>"
    exit 1
    ;;
esac
