#!/usr/bin/env python3
"""Measure HTTM OUT -> first nonzero I2S left-channel word from logic CSV.

CSV header defaults: time_s,key,bclk,lrclk,din (0/1). Each captured note
must begin after silence: disable WAV, echo and metronome, release FSR,
then press one key at a time. Capture >=10 MHz, preferably 20 MHz or more.
Do not use a speaker output as a logic-analyzer input.
"""
import argparse
import csv
import statistics
from pathlib import Path


def measure(path, columns, min_word):
    presses = []
    previous = None
    pressed_at = None
    start_of_word = None
    word = 0
    bits = 0
    last_nonzero_at = None
    capture_start = None
    with path.open(newline="") as f:
        reader = csv.DictReader(f)
        if not set(columns).issubset(reader.fieldnames or []):
            raise ValueError(f"CSV must contain columns {columns}; found {reader.fieldnames}")
        for row in reader:
            t = float(row[columns[0]])
            key, bclk, lrclk, din = (int(row[x]) for x in columns[1:])
            if previous is None:
                capture_start = t
                previous = (key, bclk, lrclk, din)
                continue
            old_key, old_bclk, old_lrclk, _ = previous
            if not old_key and key:
                if pressed_at is not None:
                    raise ValueError("Another press occurred before a nonzero I2S sample; isolate the notes")
                if t - (last_nonzero_at if last_nonzero_at is not None else capture_start) < 0.05:
                    raise ValueError("Keep at least 50 ms of digital silence before every press")
                pressed_at = t
            if old_lrclk and not lrclk:
                bits = 0
                word = 0
                start_of_word = None
            if not old_bclk and bclk and not lrclk and bits < 16:
                if bits == 0:
                    start_of_word = t
                word = (word << 1) | din
                bits += 1
                if bits == 16 and pressed_at is not None and start_of_word >= pressed_at:
                    value = word if word < 32768 else word-65536
                    if abs(value) >= min_word:
                        presses.append((pressed_at, start_of_word, (start_of_word-pressed_at)*1000))
                        pressed_at = None
                        last_nonzero_at = start_of_word
                elif bits == 16 and pressed_at is None:
                    value = word if word < 32768 else word-65536
                    if abs(value) >= min_word:
                        last_nonzero_at = start_of_word
            previous = key, bclk, lrclk, din
    if pressed_at is not None:
        raise ValueError("Last press produced no detected audio word; check capture length and I2S wiring")
    if not presses:
        raise ValueError("No valid press/audio pair found")
    return presses


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("csv", type=Path)
    ap.add_argument("--columns", nargs=5, default=["time_s", "key", "bclk", "lrclk", "din"])
    ap.add_argument("--min-word", type=int, default=1,
                    help="Minimum absolute PCM word; default 1 detects the first nonzero sample")
    ap.add_argument("--output", type=Path, default=Path("httm_to_i2s_latency.csv"))
    args = ap.parse_args()
    if args.min_word < 1 or args.min_word > 32767:
        ap.error("--min-word must be 1..32767")
    records = measure(args.csv, args.columns, args.min_word)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["press_time_s", "first_audio_word_s", "latency_ms"])
        writer.writerows(records)
    values = [r[2] for r in records]
    print(f"N={len(values)} mean={statistics.mean(values):.3f} ms max={max(values):.3f} ms")
    print("Meets <=10 ms from measured electrical HTTM transition:", max(values) <= 10)
    print("This does not include finger-to-HTTM sensing time or acoustic speaker delay.")
    print(args.output)


if __name__ == "__main__":
    main()
