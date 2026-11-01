import wave
import math
import struct
import random
import os

SAMPLE_RATE = 22050

def make_wav(path, duration, generator_fn):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    num_samples = int(duration * SAMPLE_RATE)
    with wave.open(path, 'wb') as wav:
        wav.setnchannels(1)      # mono
        wav.setsampwidth(2)      # 16-bit
        wav.setframerate(SAMPLE_RATE)
        
        frames = bytearray()
        for i in range(num_samples):
            t = float(i) / SAMPLE_RATE
            val = generator_fn(t, duration, i)
            val = max(-1.0, min(1.0, val))
            sample = int(val * 32767.0)
            frames.extend(struct.pack('<h', sample))
        wav.writeframes(frames)
    print(f"Generated {path} ({duration}s)")

# 1. Sualtı Uğultusu (Deep Underwater Ambient Drone / Ocean Rumble)
# 8 seconds seamless loop: 45Hz + 62Hz + 88Hz + gentle filtered swell
def gen_underwater_ambiance(t, duration, i):
    # Deep fundamental rumbles
    base = 0.38 * math.sin(2.0 * math.pi * 50.0 * t)
    harmonic1 = 0.22 * math.sin(2.0 * math.pi * 75.0 * t + 0.5)
    harmonic2 = 0.15 * math.sin(2.0 * math.pi * 110.0 * t + 1.2)
    # Slow rhythmic oceanic swell (period ~4s)
    swell = 0.7 + 0.3 * math.sin(2.0 * math.pi * (1.0 / 4.0) * t)
    # Very gentle muffled low-pass hiss
    noise = (random.random() * 2.0 - 1.0) * 0.04
    # Loop boundary smooth crossfade
    fade = 1.0
    fade_len = 0.5
    if t < fade_len:
        fade = 0.5 - 0.5 * math.cos(math.pi * t / fade_len)
    elif t > duration - fade_len:
        fade = 0.5 - 0.5 * math.cos(math.pi * (duration - t) / fade_len)
    return (base + harmonic1 + harmonic2 + noise) * swell * fade * 0.75

# 2. Su Kabarcığı (Bubbles / Bubble Pop)
# Sweeping sine pop 320Hz -> 780Hz with rapid envelope decay
def gen_bubble(t, duration, i):
    if t > 0.35:
        return 0.0
    # Frequency ramps upwards like a bubble release
    freq = 320.0 + 900.0 * (t / 0.35)**1.5
    env = math.exp(-t * 16.0)
    # Plop transient
    return math.sin(2.0 * math.pi * freq * t) * env * 0.85

# 3. Plastik Yutma / Boğulma / Hasar Sesi (Suffocation / Muffled Impact)
# Low frequency muffled thud + distorted crunch
def gen_damage(t, duration, i):
    if t > 0.55:
        return 0.0
    env = math.exp(-t * 9.0)
    thud = math.sin(2.0 * math.pi * (110.0 - 70.0 * (t / 0.55)) * t)
    # Crunch transient
    crunch = (random.random() * 2.0 - 1.0) * math.exp(-t * 22.0) * 0.5
    return (thud * 0.8 + crunch) * env * 0.9

# 4. Yerli Denizanası Şifa Çanı (Heal Ping / Shimmering Chime)
# Ethereal underwater bell: 528Hz (Love/DNA repair frequency) + 1056Hz harmonic with slow chime ring
def gen_heal(t, duration, i):
    if t > 1.2:
        return 0.0
    env = math.exp(-t * 3.8)
    f1 = math.sin(2.0 * math.pi * 528.0 * t)
    f2 = 0.45 * math.sin(2.0 * math.pi * 1056.0 * t)
    f3 = 0.25 * math.sin(2.0 * math.pi * 1584.0 * t)
    # gentle tremolo
    trem = 1.0 + 0.15 * math.sin(2.0 * math.pi * 8.0 * t)
    return (f1 + f2 + f3) * env * trem * 0.75

# 5. Atık Toplama Sesi (Trash Pickup Chime)
# Bright pleasant two-tone ding (784Hz -> 1046Hz, G5 -> C6)
def gen_pickup(t, duration, i):
    if t > 0.4:
        return 0.0
    env = math.exp(-t * 11.0)
    freq = 784.0 if t < 0.09 else 1046.5
    return math.sin(2.0 * math.pi * freq * t) * env * 0.75

make_wav("assets/audio/underwater_ambiance.wav", 8.0, gen_underwater_ambiance)
make_wav("assets/audio/bubble.wav", 0.4, gen_bubble)
make_wav("assets/audio/damage.wav", 0.6, gen_damage)
make_wav("assets/audio/heal.wav", 1.3, gen_heal)
make_wav("assets/audio/pickup.wav", 0.45, gen_pickup)
print("All audio files generated successfully!")

