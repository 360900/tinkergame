#!/usr/bin/env python3
"""Structural check for a binary shortcuts.vdf: exits 1 with a reason when the
byte stream is not well formed. Used by tests/unit/shortcutwrite.bats."""
import sys

def parse(buf, pos):
    while pos < len(buf):
        t = buf[pos]; pos += 1
        if t == 0x08:
            return pos, None
        if t not in (0x00, 0x01, 0x02):
            return pos, f"unknown type 0x{t:02x} at offset {pos-1}"
        end = buf.find(b'\x00', pos)
        if end < 0:
            return pos, f"unterminated key at offset {pos}"
        pos = end + 1
        if t == 0x00:
            pos, err = parse(buf, pos)
            if err:
                return pos, err
        elif t == 0x01:
            end = buf.find(b'\x00', pos)
            if end < 0:
                return pos, f"unterminated string at offset {pos}"
            pos = end + 1
        else:
            if pos + 4 > len(buf):
                return pos, f"truncated int32 at offset {pos}"
            pos += 4
    return pos, "file ends without a closing 0x08"

buf = open(sys.argv[1], 'rb').read()
pos, err = parse(buf, 0)
if err:
    print(err); sys.exit(1)
if pos != len(buf):
    print(f"{len(buf) - pos} trailing bytes after the final 0x08"); sys.exit(1)
print("ok")
