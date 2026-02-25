# Smart Chime & Audio Casting

A simple, mainstream way to handle periodic chimes and network audio on Ubuntu 24.04 (PipeWire).

## Features
1. **Periodic Chimes**: Plays sounds (like clock bells) based on a schedule.
2. **Audio Casting**: Makes your computer a receiver for Apple (AirPlay) and Linux (Lag-free TCP).
3. **HA Friendly**: Optimized for Home Assistant to update settings locally.

## Setup

### 1. Enable Periodic Chimes
Add this line to your crontab (`crontab -e`) to check the schedule every minute:
```cron
* * * * * /home/onur/Projects/smart-chime/bin/tick.sh
```

### 2. Enable Audio Casting
Run this script to make your machine visible on the network:
```bash
./bin/enable-casting.sh
```

## Configuration

- **Schedule**: Edit `config/schedule.txt` to change when sounds play. Format: `HH:MM filename.mp3`
- **Settings**: Edit `config/soundctl.conf` to change default volume or toggle chimes on/off.

## Manual Usage

**Play a chime manually:**
```bash
./bin/smart-chime.sh sounds/1_single.mp3 0.8
```
*(The `0.8` is the volume multiplier, where 1.0 is 100%)*

## Files
- `bin/tick.sh`: The scheduler (called by cron).
- `bin/smart-chime.sh`: The mainstream audio engine (PipeWire native).
- `bin/enable-casting.sh`: Universal script to enable network audio.
