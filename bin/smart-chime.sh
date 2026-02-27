#!/usr/bin/env bash
set -euo pipefail

# Mainstream way to play sounds in the current user's audio session.
# Usage: smart-chime.sh <filename> [volume_multiplier]

# Cron-safe XDG_RUNTIME_DIR resolution
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"

# --- Setup & Configuration ---
CONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)/soundctl.conf"
if [[ -f "$CONF" ]]; then source "$CONF"; else echo "Error: Config not found" >&2; exit 1; fi
SOUND_FILE="${1:-}"
VOLUME="${2:-1.0}" # 1.0 is 100%

if [[ -z "$SOUND_FILE" ]]; then
    echo "Usage: $0 <filename.mp3> [volume]"
    exit 1
fi

FILE_PATH="${SOUNDS_DIR}/${SOUND_FILE}"
if [[ ! -f "$FILE_PATH" ]]; then
    # Try absolute path
    if [[ -f "$SOUND_FILE" ]]; then
        FILE_PATH="$SOUND_FILE"
    else
        echo "Error: Sound file not found: $FILE_PATH"
        exit 1
    fi
fi

# Use pw-play (PipeWire native) with music role.
# --volume=FLOAT (1.0 is original)
pw-play --media-role=music --volume="$VOLUME" "$FILE_PATH"
