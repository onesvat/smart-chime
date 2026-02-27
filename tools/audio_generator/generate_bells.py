"""
Roman Chime Audio Generator v4 — Pure Additive Synthesis

Spectral fingerprints extracted from original I_pro, V_pro, X_pro samples.
Generates bell sounds from scratch using numpy — no external audio files needed.
"""

import numpy as np
from scipy.io import wavfile
import os

SAMPLE_RATE = 44100

# =============================================================================
# BELL DEFINITIONS — Spectral fingerprints from original samples
# Each partial: (freq_ratio, relative_amplitude, decay_rate)
#   - freq_ratio: multiplier of base frequency
#   - relative_amplitude: loudness relative to others (will be normalized)
#   - decay_rate: higher = faster decay. High partials decay faster (physics).
# =============================================================================

BELL_I = {
    'name': 'I (Tiz / High Bell)',
    'base_freq': 646.0,   # Original
    'duration': 6.5,       # Micro-tuned
    'gain': 0.95,          # Micro-tuned
    'partials': [
        # (ratio,  amplitude, decay)
        (1.00,     1.000,     1.0),   # 646 Hz — fundamental
        (1.63,     1.331,     1.3),
        (2.39,     4.583,     1.6),
        (3.26,     5.936,     2.0),
        (4.21,     2.597,     2.8),
        (5.23,     0.874,     3.5),
    ]
}

BELL_V = {
    'name': 'V (Orta / Mid Bell)',
    'base_freq': 480.0,   # Original
    'duration': 8.5,       # Micro-tuned
    'gain': 1.0,
    'partials': [
        (1.00,     1.000,     0.8),   # 480 Hz — fundamental
        (1.65,     1.552,     1.0),
        (2.43,     4.850,     1.3),
        (2.91,     0.614,     1.5),
        (3.34,     6.193,     1.6),
        (4.35,     7.759,     2.0),
        (5.46,     2.274,     2.8),
        (5.85,     0.510,     3.0),
        (6.65,     2.509,     3.5),
        (7.90,     1.287,     4.0),
    ]
}

BELL_X = {
    'name': 'X (Bas / Deep Bell)',
    'base_freq': 528.0,   # Original
    'duration': 12.0,      # Micro-tuned
    'gain': 1.1,           # Micro-tuned
    'partials': [
        (1.00,     1.000,     0.5),   # 528 Hz — fundamental
        (1.48,     0.938,     0.7),
        (2.05,     4.476,     0.9),
        (2.16,     0.606,     1.0),
        (2.70,     3.313,     1.2),
        (3.41,     2.979,     1.5),
        (4.18,     1.979,     2.0),
        (5.01,     1.696,     2.5),
        (5.88,     0.802,     3.0),
        (6.80,     0.392,     3.5),
    ]
}

# =============================================================================
# SYNTHESIZER
# =============================================================================

def synthesize_bell(bell_def):
    """Generate a single bell strike using additive synthesis.
    
    Each partial is a sine wave with its own frequency, amplitude,
    and exponential decay rate. Higher partials decay faster,
    mimicking real bell physics.
    """
    sr = SAMPLE_RATE
    duration = bell_def['duration']
    base_freq = bell_def['base_freq']
    partials = bell_def['partials']
    
    n_samples = int(sr * duration)
    t = np.linspace(0, duration, n_samples, endpoint=False)
    signal = np.zeros(n_samples, dtype=np.float64)
    
    for freq_ratio, amplitude, decay_rate in partials:
        freq = base_freq * freq_ratio
        # Exponential decay envelope per partial
        envelope = amplitude * np.exp(-decay_rate * t)
        # Add slight frequency jitter for organic feel (±0.1%)
        signal += envelope * np.sin(2 * np.pi * freq * t)
    
    # Soft attack: 5ms raised-cosine fade-in (prevents click)
    attack_samples = int(sr * 0.005)
    attack_curve = 0.5 * (1 - np.cos(np.pi * np.arange(attack_samples) / attack_samples))
    signal[:attack_samples] *= attack_curve
    
    # Tail cleanup: ensure signal fades to true zero
    # Apply gentle fade in last 200ms
    tail_samples = int(sr * 0.2)
    tail_curve = np.linspace(1, 0, tail_samples) ** 2  # quadratic ease-out
    signal[-tail_samples:] *= tail_curve
    
    # Peak-normalize to 0.85 (-1.4 dBFS) — leaves headroom for mixing
    # Apply custom gain per bell type
    gain = bell_def.get('gain', 1.0)
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak * 0.85 * gain
    
    return signal


def signal_to_int16(signal):
    """Convert float64 signal [-1, 1] to int16."""
    return np.clip(signal * 32767, -32768, 32767).astype(np.int16)


# =============================================================================
# MIX ENGINE
# =============================================================================

def create_dynamic_chime(strikes_info, filename):
    """Mix multiple bell strikes with dynamic cadence timing.
    
    strikes_info: list of (bell_signal, symbol_type)
    """
    # Dynamic cadence: wait time after previous bell type (ms)
    cadence = {
        'I': 1500,   # High bells: enough space to hear each strike
        'V': 2500,   # Mid bells: moderate spacing
        'X': 3500,   # Deep bells: stately, slow
    }
    
    preroll_ms = 1500  # 1.5s wake-up time for audio device
    
    # Calculate required buffer length
    offsets = []
    current_offset = preroll_ms
    last_type = None
    
    for i, (bell_signal, sym_type) in enumerate(strikes_info):
        if i > 0:
            current_offset += cadence.get(last_type, 1000)
        offsets.append(current_offset)
        last_type = sym_type
    
    # Total length: last offset + length of last bell
    last_bell_len_ms = len(strikes_info[-1][0]) / SAMPLE_RATE * 1000
    total_ms = offsets[-1] + last_bell_len_ms + 500  # 500ms safety tail
    total_samples = int(SAMPLE_RATE * total_ms / 1000)
    
    # Mix via superposition (simple addition in float64 — no clipping)
    mixed = np.zeros(total_samples, dtype=np.float64)
    
    # Add a faint analog "tape hiss / mechanism" noise to wake up the amplifier safely
    wake_samples = int(SAMPLE_RATE * (preroll_ms / 1000.0))
    wake_signal = np.random.normal(0, 0.0004, wake_samples)
    
    # Fade in and out the wake signal smoothly
    fade_len = int(SAMPLE_RATE * 0.5)
    fade_in = np.linspace(0, 1, fade_len)
    fade_out = np.linspace(1, 0, fade_len)
    if wake_samples > 2 * fade_len:
        wake_signal[:fade_len] *= fade_in
        wake_signal[-fade_len:] *= fade_out
    
    mixed[:wake_samples] += wake_signal
    
    for (bell_signal, _), offset_ms in zip(strikes_info, offsets):
        start_sample = int(SAMPLE_RATE * offset_ms / 1000)
        end_sample = start_sample + len(bell_signal)
        # Extend buffer if needed
        if end_sample > len(mixed):
            mixed = np.pad(mixed, (0, end_sample - len(mixed)))
        mixed[start_sample:end_sample] += bell_signal
    
    # Master processing
    # 1. Peak-normalize to 0.85 (Original clean level)
    peak = np.max(np.abs(mixed))
    if peak > 0:
        mixed = mixed / peak * 0.85
    
    # 2. Final tail fade: last 1 second exponential fade-out
    tail_duration = min(1.0, len(mixed) / SAMPLE_RATE * 0.15)
    tail_samples = int(SAMPLE_RATE * tail_duration)
    if tail_samples > 0 and tail_samples <= len(mixed):
        tail_curve = np.exp(-5 * np.linspace(0, 1, tail_samples))
        mixed[-tail_samples:] *= tail_curve
    
    # 3. Trim trailing silence (below -60 dBFS)
    threshold = 0.001  # ~-60 dBFS
    # Find last sample above threshold
    above = np.where(np.abs(mixed) > threshold)[0]
    if len(above) > 0:
        last_audible = above[-1]
        # Keep 100ms of silence after last audible sample
        trim_point = min(last_audible + int(SAMPLE_RATE * 0.1), len(mixed))
        mixed = mixed[:trim_point]
    
    # Export as 16-bit WAV
    output_path = os.path.join("sounds", "ai_generated", filename)
    wavfile.write(output_path, SAMPLE_RATE, signal_to_int16(mixed))
    
    duration_s = len(mixed) / SAMPLE_RATE
    print(f"  {filename}: {duration_s:.1f}s, peak={20*np.log10(np.max(np.abs(mixed))+1e-10):.1f} dBFS")


# =============================================================================
# MAIN — Generate all 13 hour chimes
# =============================================================================

if __name__ == '__main__':
    print("Synthesizing bell samples...")
    sig_i = synthesize_bell(BELL_I)
    sig_v = synthesize_bell(BELL_V)
    sig_x = synthesize_bell(BELL_X)
    print(f"  I: {len(sig_i)/SAMPLE_RATE:.1f}s | V: {len(sig_v)/SAMPLE_RATE:.1f}s | X: {len(sig_x)/SAMPLE_RATE:.1f}s")
    
    # Hour mappings (Base-4 Roman system, day start = 10:00 AM)
    mappings = {
        1:  [(sig_i, 'I')],
        2:  [(sig_i, 'I'), (sig_i, 'I')],
        3:  [(sig_i, 'I'), (sig_i, 'I'), (sig_i, 'I')],
        4:  [(sig_v, 'V')],
        5:  [(sig_v, 'V'), (sig_i, 'I')],
        6:  [(sig_v, 'V'), (sig_i, 'I'), (sig_i, 'I')],
        7:  [(sig_v, 'V'), (sig_i, 'I'), (sig_i, 'I'), (sig_i, 'I')],
        8:  [(sig_x, 'X')],
        9:  [(sig_x, 'X'), (sig_i, 'I')],
        10: [(sig_x, 'X'), (sig_i, 'I'), (sig_i, 'I')],
        11: [(sig_x, 'X'), (sig_i, 'I'), (sig_i, 'I'), (sig_i, 'I')],
        12: [(sig_x, 'X'), (sig_v, 'V')],
        13: [(sig_x, 'X'), (sig_v, 'V'), (sig_i, 'I')],
    }
    
    os.makedirs(os.path.join("sounds", "ai_generated"), exist_ok=True)
    
    print("\nGenerating chimes...")
    for hour, strikes in mappings.items():
        create_dynamic_chime(strikes, f"hour_{hour}.wav")
    
    print("\nv4: Additive Synthesis — complete.")
