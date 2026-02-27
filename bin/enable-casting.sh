#!/usr/bin/env bash
set -euo pipefail

# --- Universal Linux Audio Casting Enabler (Optimized) ---

FRIENDLY_NAME="htpc"
LAN_IFACE="enp34s0"
PORT=4713

echo "--- 1. Enabling AirPlay (Apple Casting) ---"
if systemctl --user list-unit-files | grep -q "shairport-sync.service"; then
    systemctl --user restart shairport-sync.service
    echo "AirPlay Receiver active."
else
    echo "Notice: shairport-sync.service not found."
fi

echo ""
echo "--- 2. Enabling Linux-to-Linux (Lag-Free) Casting ---"
if command -v pactl >/dev/null 2>&1; then
    # Detect LAN IP (192.168.x.x) from the primary interface
    LAN_IP=$(ip -4 addr show "$LAN_IFACE" 2>/dev/null \
        | grep -oP '192\.168\.\d+\.\d+' | head -1) || true

    if [[ -z "$LAN_IP" ]]; then
        echo "Warning: Could not detect LAN IP on ${LAN_IFACE}, falling back to 0.0.0.0"
        LAN_IP="0.0.0.0"
    fi

    # Check if TCP module is already loaded with the correct listen address
    ALREADY_LOADED=false
    if pactl list modules short 2>/dev/null | grep -q "module-native-protocol-tcp.*listen=${LAN_IP}"; then
        ALREADY_LOADED=true
        echo "TCP module already loaded on ${LAN_IP}:${PORT}, skipping."
    fi

    if [[ "$ALREADY_LOADED" == false ]]; then
        # Clean up previous instances
        pactl unload-module module-zeroconf-publish 2>/dev/null || true
        pactl unload-module module-native-protocol-tcp 2>/dev/null || true

        # Get default sink and set friendly name BEFORE publishing via zeroconf.
        # module-zeroconf-publish reads the sink description at load time.
        DEFAULT_SINK=$(pactl info | grep "Default Sink:" | awk '{print $3}')
        pactl set-sink-description "$DEFAULT_SINK" "$FRIENDLY_NAME" 2>/dev/null || true
        echo "Sink description set to: ${FRIENDLY_NAME}"

        # Load TCP protocol bound to LAN only
        pactl load-module module-native-protocol-tcp \
            auth-anonymous=1 port="$PORT" listen="$LAN_IP"
        echo "TCP module loaded on ${LAN_IP}:${PORT}"

        # Publish via zeroconf (now picks up the short name)
        pactl load-module module-zeroconf-publish
        echo "Network Sink: [${FRIENDLY_NAME}] is now visible."
    fi
else
    echo "Error: 'pactl' not found."
fi

echo ""
echo "--- 3. Low-Latency Tuning (Receiver Side) ---"
# Set PipeWire quantum to 256/48000 (~5.3ms) for low-latency network audio.
# This is the receiver-side knob; senders should also set PULSE_LATENCY_MSEC=30.
if command -v pw-metadata >/dev/null 2>&1; then
    pw-metadata -n settings 0 clock.force-quantum 256 2>/dev/null || true
    echo "PipeWire quantum set to 256 samples (~5.3ms at 48kHz)."
    echo "Hint (sender): export PULSE_SERVER=tcp:htpc.local:${PORT} PULSE_LATENCY_MSEC=30"
else
    echo "Notice: pw-metadata not found, skipping latency tuning."
fi

echo ""
echo "Success: Audio casting features have been activated."
