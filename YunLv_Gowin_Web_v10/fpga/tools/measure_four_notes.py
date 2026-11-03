#!/usr/bin/env python3
"""Measure the four fundamental peaks from a microphone PCM WAV recording.

Example: python measure_four_notes.py four_keys.wav --start 0.5 --seconds 2
Record normal PLAY LIVE with FSR released, SW3 effect and beat both off.
Press D4, F4, A4 and C5 together and hold through the selected interval.
The microphone WAV is evidence, not a measurement of electrical latency.
"""
import argparse
import csv
import math
import wave
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


NOTES = {"C4": 261.626, "D4": 293.665, "E4": 329.628,
         "F4": 349.228, "G4": 391.995, "A4": 440.000,
         "B4": 493.883, "C5": 523.251}


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        if w.getcomptype() != "NONE" or w.getnchannels() not in (1, 2):
            raise ValueError("Only uncompressed mono/stereo PCM WAV is supported")
        rate, channels, width = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width == 1:
        data = np.frombuffer(raw, np.uint8).astype(np.float64) - 128
        full_scale = 128
    elif width == 2:
        data = np.frombuffer(raw, "<i2").astype(np.float64)
        full_scale = 32768
    elif width == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        x = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        data = ((x ^ 0x800000) - 0x800000).astype(np.float64)
        full_scale = 8388608
    elif width == 4:
        data = np.frombuffer(raw, "<i4").astype(np.float64)
        full_scale = 2147483648
    else:
        raise ValueError("Unsupported PCM sample width")
    return rate, data.reshape(-1, channels).mean(axis=1), full_scale


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("wav", type=Path)
    ap.add_argument("--notes", nargs=4, default=["D4", "F4", "A4", "C5"], choices=NOTES)
    ap.add_argument("--start", type=float, default=0.5, help="Start of stable held notes in seconds")
    ap.add_argument("--seconds", type=float, default=1.5)
    ap.add_argument("--output", type=Path, default=Path("four_notes_spectrum.png"))
    args = ap.parse_args()
    if args.start < 0 or args.seconds < 0.35 or len(set(args.notes)) < 4:
        ap.error("Use four distinct notes and at least 0.35 s of stable audio")
    rate, samples, full_scale = read_wav(args.wav)
    clip = samples[int(args.start * rate):int((args.start + args.seconds) * rate)]
    if len(clip) < rate * 0.35:
        ap.error("Recording is shorter than the selected interval")
    if np.max(np.abs(clip)) < 0.002 * full_scale:
        ap.error("Recording is nearly silent")
    clipped = np.mean(np.abs(clip) >= full_scale * 0.995) * 100
    window = np.hanning(len(clip))
    nfft = 1 << (max(len(clip) * 4, 65536) - 1).bit_length()
    spectrum = np.abs(np.fft.rfft((clip - np.mean(clip)) * window, n=nfft))
    hz = np.fft.rfftfreq(nfft, 1 / rate)
    reference = max(spectrum[(hz >= 240) & (hz <= 550)].max(), 1e-12)
    rows = []
    for name in args.notes:
        target = NOTES[name]
        band = np.flatnonzero((hz >= target * 2 ** (-35 / 1200)) &
                              (hz <= target * 2 ** (35 / 1200)))
        k = int(band[np.argmax(spectrum[band])])
        freq = hz[k]
        # Parabolic interpolation around a windowed spectral maximum.
        if 0 < k < len(spectrum) - 1:
            a, b, c = np.log(np.maximum(spectrum[k-1:k+2], 1e-12))
            shift = 0.5 * (a-c) / (a-2*b+c) if a-2*b+c else 0
            freq += float(np.clip(shift, -0.5, 0.5)) * rate / nfft
        db = 20 * np.log10(max(spectrum[k], 1e-12) / reference)
        cents = 1200 * math.log2(freq / target)
        rows.append((name, target, freq, cents, db, "candidate" if db >= -25 else "weak"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(11, 4.6))
    band = (hz >= 240) & (hz <= 550)
    ax.plot(hz[band], 20*np.log10(np.maximum(spectrum[band], 1e-12)/reference))
    for name, target, freq, _, _, _ in rows:
        ax.axvline(target, linestyle="--", linewidth=0.9, label=f"{name} {target:.1f} Hz")
        ax.plot(freq, 20*np.log10(max(spectrum[np.argmin(abs(hz-freq))], 1e-12)/reference), "o")
    ax.set(xlabel="Frequency (Hz)", ylabel="Relative level (dB)",
           title="Four simultaneous notes: fundamental peaks", xlim=(240, 550), ylim=(-70, 5))
    ax.legend(ncol=2, fontsize=8)
    fig.tight_layout()
    fig.savefig(args.output, dpi=160)
    plt.close(fig)
    csv_file = args.output.with_suffix(".csv")
    with csv_file.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["note", "target_hz", "candidate_peak_hz", "error_cents", "relative_db", "status"])
        writer.writerows(rows)
    print("WAV:", args.wav, "clipped samples:", f"{clipped:.3f}%")
    for name, target, freq, cents, db, status in rows:
        print(f"{name}: target {target:.2f} Hz; candidate {freq:.2f} Hz; {cents:+.1f} cents; {db:.1f} dB [{status}]")
    print("Inspect plot for nearby harmonics/background; candidate peaks alone do not prove independent voices.")
    print(args.output, csv_file)


if __name__ == "__main__":
    main()
