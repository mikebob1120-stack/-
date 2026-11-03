#!/usr/bin/env python3
"""Rebuild the PROGMEM gzip header after changing phone_source files."""
import gzip
from pathlib import Path

root = Path(__file__).parent
files = (('PHONE_INDEX', 'index.html'), ('PHONE_RENDERER', 'renderer.js'),
         ('PHONE_APP', 'app.js'), ('PHONE_WORKER', 'worker-source.js'))
lines = ['// Generated from phone_source by build_phone_assets.py.\n',
         '#pragma once\n#include <pgmspace.h>\n']
for symbol, name in files:
    data = gzip.compress((root / 'phone_source' / name).read_bytes(), compresslevel=9, mtime=0)
    lines.append(f'static const uint8_t {symbol}[] PROGMEM = {{\n')
    for i in range(0, len(data), 24):
        lines.append('  ' + ','.join(f'0x{b:02x}' for b in data[i:i+24]) + ',\n')
    lines.append('};\n')
(root / 'phone_assets.h').write_text(''.join(lines))
print('Built', root / 'phone_assets.h')
