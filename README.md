# Smart Chime & Audio Casting

A simple, mainstream way to handle periodic chimes and network audio on Ubuntu 24.04 using PipeWire.

## Features
1. **Periodic Chimes**: Plays sounds based on a local schedule.
2. **Audio Casting**: A universal script to enable your computer as a receiver for Apple (AirPlay) and Linux (Lag-free TCP).
3. **Purely Local**: High reliability with zero external dependencies.

## Setup

### 1. Enable Periodic Chimes
Add this line to your crontab (`crontab -e`) to check the schedule every minute:
```cron
* * * * * /home/onur/Projects/smart-chime/bin/tick.sh
```

### 2. Enable Audio Casting
Run this script to make your machine visible on the network for AirPlay and other Linux machines:
```bash
./bin/enable-casting.sh
```

## Configuration

- **Schedule**: Edit `config/schedule.txt` to change when sounds play. 
  - Format: `HH:MM filename.mp3`
- **Settings**: Edit `config/soundctl.conf` to change default volume or toggle the system on/off.
  - `BELLS_ENABLED="on"`
  - `DEFAULT_VOLUME="0.8"`

## Manual Usage

**Play a chime manually:**
```bash
./bin/smart-chime.sh 1_single.mp3 0.5
```
*(The `0.5` is the volume multiplier, where 1.0 is 100%)*

## Files
- `bin/tick.sh`: The scheduler (called by cron).
- `bin/smart-chime.sh`: The audio engine (PipeWire native).
- `bin/enable-casting.sh`: Universal script to activate network audio.
