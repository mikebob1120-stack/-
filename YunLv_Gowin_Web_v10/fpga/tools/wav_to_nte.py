#!/usr/bin/env python3
"""Estimate one melody note per fixed-duration step in a PCM WAV.

This is a helper for clear, monophonic, evenly spaced C4..C5 melodies.
It refuses silence, out-of-range notes and obvious chords/mixes rather than
silently making an incorrect guided score. It cannot transcribe full songs.

Example: python wav_to_nte.py DEMO.WAV --step-ms 500
"""
import argparse
import math
from pathlib import Path
import re
import wave

import numpy as np

NAMES = ("C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5")
FREQUENCIES = np.array([261.625565, 293.664768, 329.627557, 349.228231,
                        391.995436, 440.0, 493.883301, 523.251131])


def load_pcm(path: Path):
    with wave.open(str(path), "rb") as wav:
        if wav.getcomptype() != "NONE":
            raise ValueError("需要未压缩 PCM WAV")
        sample_rate = wav.getframerate()
        channels = wav.getnchannels()
        width = wav.getsampwidth()
        raw = wav.readframes(wav.getnframes())
    if width == 1:
        values = np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128.0
    elif width == 2:
        values = np.frombuffer(raw, dtype="<i2").astype(np.float64)
    elif width == 3:
        data = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        signed = data[:, 0] | (data[:, 1] << 8) | (data[:, 2] << 16)
        values = ((signed ^ 0x800000) - 0x800000).astype(np.float64)
    elif width == 4:
        values = np.frombuffer(raw, dtype="<i4").astype(np.float64)
    else:
        raise ValueError("仅支持 8/16/24/32 位整数 PCM")
    if channels not in (1, 2) or sample_rate < 8000 or sample_rate > 96000:
        raise ValueError("仅支持单/双声道、8～96 kHz")
    values = values.reshape(-1, channels).mean(axis=1)
    return sample_rate, values


def estimate_note(segment, sample_rate, max_cents):
    if segment.size < sample_rate * 0.06:
        return None, "片段太短"
    # Inspect at most 0.22 s around the step's center to avoid adjacent notes.
    length = min(segment.size, int(sample_rate * 0.22))
    offset = (segment.size - length) // 2
    signal = segment[offset:offset + length]
    if np.sqrt(np.mean(signal * signal)) < 6:
        return None, "静音"
    signal = (signal - np.mean(signal)) * np.hanning(length)
    nfft = 1 << (max(8192, 4 * length) - 1).bit_length()
    spectrum = np.abs(np.fft.rfft(signal, n=nfft))
    hz = np.fft.rfftfreq(nfft, 1 / sample_rate)
    band = np.flatnonzero((hz >= 240) & (hz <= 550))
    peak = band[np.argmax(spectrum[band])]
    peak_hz = hz[peak]
    nearest = int(np.argmin(np.abs(1200 * np.log2(peak_hz / FREQUENCIES))))
    cents = abs(1200 * math.log2(peak_hz / FREQUENCIES[nearest]))
    if cents > max_cents:
        return None, f"检测到约 {peak_hz:.0f} Hz，不属于八个琴键（相差 {cents:.0f} 音分）"
    # Multiple strong, separated peaks usually mean a chord or accompaniment.
    away = band[np.abs(hz[band] - peak_hz) > 19]
    if away.size and spectrum[away].max() > 0.57 * spectrum[peak]:
        return None, "疑似和弦或伴奏，不能可靠识别为单音"
    return nearest, f"{NAMES[nearest]} ({peak_hz:.1f} Hz)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav", type=Path, help="输入的 PCM WAV，例如 SONG1.WAV")
    parser.add_argument("--step-ms", type=float, required=True,
                        help="每个音符的时长（毫秒），例如 500；不支持自动检测节拍")
    parser.add_argument("--timed", action="store_true", help="生成带固定步长的 NTE2")
    parser.add_argument("--offset-ms", type=float, default=0,
                        help="歌曲开头要跳过的时间（毫秒），默认为 0")
    parser.add_argument("--max-cents", type=float, default=65,
                        help="距离八个音符的最大音高偏差，默认 65 音分")
    args = parser.parse_args()
    if args.step_ms < 80 or args.offset_ms < 0:
        parser.error("--step-ms 不能小于 80，--offset-ms 不能小于 0")
    if args.timed and (args.step_ms > 2550 or
                       abs(args.step_ms / 10 - round(args.step_ms / 10)) > 1e-9):
        parser.error("NTE2 步长需为 10 毫秒的整数倍，最大 2550 毫秒")
    path = args.wav
    if not re.fullmatch(r"[A-Za-z0-9_]{1,8}", path.stem):
        parser.error("先将 WAV 改成 1～8 位英文字母/数字/下划线文件名，如 SONG1.WAV")
    output = path.with_suffix(".NTE")
    try:
        rate, audio = load_pcm(path)
    except (OSError, EOFError, wave.Error, ValueError) as exc:
        parser.error(str(exc))
    step = round(args.step_ms * rate / 1000)
    start = round(args.offset_ms * rate / 1000)
    count = (len(audio) - start) // step
    if not 1 <= count <= (126 if args.timed else 256):
        parser.error(f"检测到 {count} 步；NTE2 仅支持 1～126 步，旧格式 1～256 步")
    notes = []
    problems = []
    for i in range(count):
        clip = audio[start + i * step:start + (i + 1) * step]
        note, message = estimate_note(clip, rate, args.max_cents)
        if note is None:
            problems.append(f"第 {i+1} 步：{message}")
        else:
            notes.append(1 << note)
    if problems:
        print(f"检测到 {len(problems)} 步无法可靠转写，未生成 .NTE：")
        for problem in problems[:20]:
            print("  " + problem)
        if len(problems) > 20:
            print(f"  其余 {len(problems)-20} 步省略")
        print("请用纯单旋律 WAV、核对 --step-ms / --offset-ms，或听歌后用 make_nte.py 手工录入。")
        return 2
    output.write_bytes((b"NTE2" + bytes(v for note in notes
                                         for v in (note, round(args.step_ms / 10))))
                       if args.timed else bytes(notes))
    print(f"已生成 {output}，共 {len(notes)} 步：")
    print(" ".join(NAMES[int(math.log2(mask))] for mask in notes))
    print("请试听逐项核对；本工具无法识别和弦、复杂伴奏及变速节奏。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
