#!/usr/bin/env python3
"""Make a guided-score .NTE file from a simple note sequence.

Legacy: python make_nte.py DEMO.NTE "C4 D4 E4 G4 C5 C4+E4+G4"
Timed:  python make_nte.py SONG.NTE "C4@500 D4@250 E4@750 G4@500" --timed
@N is the target interval since the previous event in milliseconds;
the first event is expected N ms after guided play begins.
Copy DEMO.NTE to the FAT16/FAT32 TF-card root; a WAV is optional.
"""
import argparse
from pathlib import Path

NOTE_BITS = {name: 1 << i for i, name in enumerate(
    ("C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5")
)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("notes", help="Space-separated notes; + for a chord")
    parser.add_argument("--timed", action="store_true",
                        help="Write NTE2 with one 10-ms duration per note")
    args = parser.parse_args()
    if args.output.suffix.upper() != ".NTE" or len(args.output.stem) > 8:
        parser.error("Use an 8.3 filename ending .NTE")
    values = []
    durations = []
    for token in args.notes.upper().split():
        chord = token
        if args.timed:
            try:
                chord, interval = token.rsplit("@", 1)
                interval = int(interval)
            except ValueError:
                parser.error(f"Timed notes need @milliseconds: {token}")
            if interval < 10 or interval > 2550 or interval % 10:
                parser.error(f"Duration must be 10..2550 ms in 10-ms steps: {token}")
            durations.append(interval // 10)
        names = chord.split("+")
        if len(names) != len(set(names)) or any(name not in NOTE_BITS for name in names):
            parser.error(f"Invalid note or chord: {chord}")
        values.append(sum(NOTE_BITS[name] for name in names))
    if not 1 <= len(values) <= (126 if args.timed else 256):
        parser.error("Timed scores allow 1..126 steps; legacy scores allow 1..256")
    if args.timed:
        data = b"NTE2" + bytes(v for pair in zip(values, durations) for v in pair)
    else:
        data = bytes(values)
    args.output.write_bytes(data)
    print(f"Wrote {args.output}: {len(values)} steps, {len(data)} bytes")


if __name__ == "__main__":
    main()
