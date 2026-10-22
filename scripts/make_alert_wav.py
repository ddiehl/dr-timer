#!/usr/bin/env python3
"""Generate the bundled alert sounds (one-off; output is committed).

  alert.wav   - 28 s of a repeating, piercing two-tone beep pattern. Under the
                30 s limit for notification sounds, so the same file serves as
                the local-notification sound and the in-app loop.
  silence.wav - 1 s of digital silence, looped while a leg counts down to keep
                the app running in the background.

Usage: python3 scripts/make_alert_wav.py   (writes into DRTimer/Resources)
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "DRTimer", "Resources")


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
    print(f"wrote {path} ({len(samples) / RATE:.1f} s)")


def tone(freq, seconds, amp=0.9):
    n = int(RATE * seconds)
    ramp = int(RATE * 0.005)  # 5 ms fade in/out: no clicks
    out = []
    for i in range(n):
        t = i / RATE
        # Fundamental plus odd harmonics: a harsher, more penetrating timbre
        # than a pure sine, which helps over cockpit noise.
        v = (math.sin(2 * math.pi * freq * t)
             + 0.35 * math.sin(2 * math.pi * 3 * freq * t)
             + 0.15 * math.sin(2 * math.pi * 5 * freq * t)) / 1.5
        env = min(1.0, i / ramp, (n - 1 - i) / ramp)
        out.append(int(32767 * amp * env * v))
    return out


def silence(seconds):
    return [0] * int(RATE * seconds)


def one_second_pattern():
    # beep-beep-beep (high/low/high) then a short gap: exactly 1.0 s.
    return (tone(1400, 0.15) + silence(0.05)
            + tone(1000, 0.15) + silence(0.05)
            + tone(1400, 0.15) + silence(0.45))


if __name__ == "__main__":
    pattern = one_second_pattern()
    write("alert.wav", pattern * 28)
    write("silence.wav", silence(1.0))
