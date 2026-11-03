"""Convert an image to the native LCD format: 480x272, 4-bit/16-color BMP.
Install Pillow once: python -m pip install Pillow
Usage: python tools/make_cover.py input.png -o COVER.BMP
"""
from pathlib import Path
import argparse
import struct
from PIL import Image, ImageOps


def convert(source, output):
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original).convert('RGBA')
        # Preserve the full composition. Pad if a different aspect ratio is used.
        image.thumbnail((480, 272), Image.Resampling.LANCZOS)
        canvas = Image.new('RGB', (480, 272), (0, 0, 0))
        canvas.paste(image, ((480-image.width)//2, (272-image.height)//2), image)
    indexed = canvas.quantize(colors=16, method=Image.Quantize.MEDIANCUT,
                              dither=Image.Dither.NONE)
    palette = indexed.getpalette()
    colors = bytes(channel for i in range(16)
                   for channel in (palette[i*3+2], palette[i*3+1], palette[i*3], 0))
    indices = indexed.tobytes()
    rows = []
    for y in range(271, -1, -1):
        row = indices[y*480:(y+1)*480]
        rows.append(bytes((row[x] << 4) | row[x+1] for x in range(0, 480, 2)))
    pixels = b''.join(rows)  # 240 bytes/row, already aligned to four bytes.
    offset = 14+40+len(colors)
    header = struct.pack('<2sIHHI', b'BM', offset+len(pixels), 0, 0, offset)
    dib = struct.pack('<IiiHHIIiiII', 40, 480, 272, 1, 4, 0, len(pixels), 2835, 2835, 16, 16)
    Path(output).write_bytes(header+dib+colors+pixels)
    print(f'Created {Path(output).resolve()}: 480x272, 4-bit, 16 colors, uncompressed BMP')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', help='source image')
    parser.add_argument('-o', '--output', default='COVER.BMP')
    args = parser.parse_args()
    convert(args.input, args.output)
