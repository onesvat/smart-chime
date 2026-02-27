# Smart Chime & Audio Casting

A simple, mainstream way to handle periodic chimes and network audio on Ubuntu 24.04 using PipeWire.

## Features
1. **Periodic Chimes**: Plays sounds based on a local schedule.
2. **Audio Casting**: A universal script to enable your computer as a receiver for Apple (AirPlay) and Linux (Lag-free TCP).
3. **Purely Local**: High reliability with zero external dependencies.

## Setup

### 1. Requirements
Ensure you have the following Python libraries installed for audio generation:
```bash
pip install numpy scipy
```

### 2. Enable Periodic Chimes
Add this line to your crontab (`crontab -e`) to check the schedule every minute:
```cron
* * * * * /path/to/smart-chime/bin/tick.sh
```

### 3. Enable Audio Casting
Run this script to make your machine visible on the network for AirPlay and other Linux machines:
```bash
./bin/enable-casting.sh
```

## Audio Generation & Chime Logic

Traditional hourly chimes (striking 1 to 24 times) are inefficient for ambient time-marking—they are too long, difficult to count at high values, and create unnecessary noise. This project uses **Encoded Audio Notification** to provide dense, readable information in seconds using three bell types: **I (High)**, **V (Mid)**, and **X (Deep)**.

### Acoustic Grounding
Regardless of the encoding system chosen, strikes always follow a **Descending Order** (X -> V -> I):
1. **X (Deep):** Struck first to create a "resonance floor" with its long 12s decay.
2. **V (Mid):** Struck next to add harmonic richness.
3. **I (High):** Struck last to provide a clear, high-frequency "dot" or "point" that cuts through the previous resonance.

### Tracking Systems Comparison
Choose a system that fits your setup. The day starts at **10:00 AM (Relative Hour 1)**.

1. **Base-4 Roman (Standard):** Current default. Balanced variation using 3 sounds. (Units: 1, 4, 8)
2. **Base-5 Binary (2-Tone):** Uses only High (I) and Mid (V) bells. Simplest to distinguish. (Units: 1, 5)
3. **Base-3 Ternary (Dense):** Highest density. Encodes up to 24 in very few strikes. (Units: 1, 3, 9)
4. **Base-6 Roman (Grid):** Optimized for 12/24 mathematical symmetry. (Units: 1, 6, 12)

| Real Time | Rel. Hr | System 1 (B4: 1,4,8) | System 2 (B5: 1,5) | System 3 (B3: 1,3,9) | System 4 (B6: 1,6,12) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **10:00** | 1 | I | I | I | I |
| **11:00** | 2 | II | II | II | II |
| **12:00** | 3 | III | III | V | III |
| **13:00** | 4 | V | IIII | VI | IIII |
| **14:00** | 5 | VI | V | VII | IIIII |
| **15:00** | 6 | VII | VI | VV | V |
| **16:00** | 7 | VIII | VII | VVI | VI |
| **17:00** | 8 | X | VIII | VVII | VII |
| **18:00** | 9 | XI | VIIII | X | VIII |
| **19:00** | 10 | XII | VV | XI | VIIII |
| **20:00** | 11 | XIII | VVI | XII | VV |
| **21:00** | 12 | XV | VVII | XV | X |
| **22:00** | 13 | XVI | VVIII | XVI | XI |
| **23:00** | 14 | XVII | VVIIII | XVII | XII |
| **00:00** | 15 | XVIII | VVV | XVV | XIII |
| **01:00** | 16 | XX | VVVI | XVVI | XIIII |
| **02:00** | 17 | XXI | VVVII | XVVII | XVIIIII |
| **03:00** | 18 | XXII | VVVIII | XX | XV |
| **04:00** | 19 | XXIII | VVVVIIII | XXI | XVI |
| **05:00** | 20 | XXV | VVVV | XXII | XVII |
| **06:00** | 21 | XXVI | VVVVI | XXV | XVIII |
| **07:00** | 22 | XXVII | VVVVII | XXVI | XIX |
| **08:00** | 23 | XXVIII | VVVVIII | XXVII | XX |
| **09:00** | 24 | XXX | VVVVIIII | XX VV | XX |

*Note: Notation shorthand uses Roman-style logic (e.g., XVI = X + V + I). To regenerate sounds based on your chosen mapping, modify and run:*
```bash
python3 tools/audio_generator/generate_bells.py
```
