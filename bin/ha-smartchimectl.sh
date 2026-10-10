#!/usr/bin/env bash
set -euo pipefail

CONF="/home/onur/Projects/smart-chime/config/soundctl.conf"

err(){ echo "ERR: $*" >&2; exit 2; }

read_var(){
  local key="$1"
  # shellcheck disable=SC2016
  grep -E "^${key}=\"" "$CONF" | head -n1 | sed -E 's/^[A-Z_]+=\"(.*)\"$/\1/'
}

write_var(){
  local key="$1" val="$2"
  # Only allow editing within HA managed section
  awk -v key="$key" -v val="$val" '
    BEGIN{in_section=0}
    /^# --- HOME ASSISTANT MANAGED SECTION ---/{in_section=1}
    /^# --- END HA MANAGED SECTION ---/{in_section=0}
    {
      if(in_section && $0 ~ "^"key"=\"") {
        print key "=\"" val "\""
      } else {
        print $0
      }
    }
  ' "$CONF" > "${CONF}.tmp"
  mv -f "${CONF}.tmp" "$CONF"
}

orig="${SSH_ORIGINAL_COMMAND:-}"
if [ -n "$orig" ]; then
  # split original command into args
  # shellcheck disable=SC2086
  set -- $orig
fi

cmd="${1:-}"
arg="${2:-}"

case "$cmd" in
  "")
    # Backward compatible: play cat-call at current DEFAULT_VOLUME
    vol="$(read_var DEFAULT_VOLUME)"
    exec /home/onur/Projects/smart-chime/bin/smart-chime.sh /home/onur/Projects/smart-chime/sounds/cat-call.mp3 "$vol"
    ;;
  get_volume)
    read_var DEFAULT_VOLUME
    ;;
  get_bells)
    read_var BELLS_ENABLED
    ;;
  set_volume)
    [ -n "$arg" ] || err "missing volume"
    # allow 0..1 with decimals
    python3 - <<PY "$arg" || exit 2
import sys
v=float(sys.argv[1])
assert 0.0 <= v <= 1.0
PY
    write_var DEFAULT_VOLUME "$arg"
    echo OK
    ;;
  play)
    [ -n "$arg" ] || err "missing relative path"
    # block absolute paths and traversal
    case "$arg" in
      /*|*..* ) err "invalid path" ;;
    esac
    full="/home/onur/Projects/smart-chime/sounds/$arg"
    [ -f "$full" ] || err "file not found"
    vol="$(read_var DEFAULT_VOLUME)"
    exec /home/onur/Projects/smart-chime/bin/smart-chime.sh "$arg" "$vol"
    ;;
  set_bells)
    [ "$arg" = "on" ] || [ "$arg" = "off" ] || err "bells must be on/off"
    write_var BELLS_ENABLED "$arg"
    echo OK
    ;;
  *)
    err "unknown command"
    ;;
esac
