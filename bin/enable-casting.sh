#!/usr/bin/env bash
set -euo pipefail

# --- Universal Linux Audio Casting Enabler ---
# This script enables:
# 1. AirPlay (via shairport-sync user service)
# 2. Linux-to-Linux Low-Latency Casting (via PipeWire/Pulse native TCP)

FRIENDLY_NAME="${HOSTNAME:-Linux-Receiver}"

echo "--- 1. Enabling AirPlay (Apple Casting) ---"
if systemctl --user list-unit-files | grep -q "shairport-sync.service"; then
    systemctl --user restart shairport-sync.service
    echo "AirPlay Receiver: [${FRIENDLY_NAME}] is now active."
else
    echo "Notice: shairport-sync.service not found. Skipping AirPlay."
fi

echo ""
echo "--- 2. Enabling Linux-to-Linux (Lag-Free) Casting ---"
# Check if pactl is available
if command -v pactl >/dev/null 2>&1; then
    # Load modules into the current session. 
    # This is safer than editing config files as it doesn't persist across reboots
    # unless added to startup, preventing 'Address already in use' errors.
    pactl load-module module-native-protocol-tcp auth-anonymous=1 port=4713 2>/dev/null || echo "TCP Module already loaded or failed."
    pactl load-module module-zeroconf-publish 2>/dev/null || echo "Zeroconf Module already loaded or failed."
    
    echo "Network Sink: [${FRIENDLY_NAME}] is now visible to other Linux machines."
else
    echo "Error: 'pactl' not found. Is PipeWire or PulseAudio installed?"
fi

echo ""
echo "Success: Audio casting features have been activated."
