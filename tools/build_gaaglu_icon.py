"""Draws the Gaaglu logo: a rounded square in four colours. Writes hub/assets/gaaglu.png."""
import struct
import zlib
from pathlib import Path

SIZE = 256
COLOURS = ((229, 57, 53), (41, 98, 255), (251, 140, 0), (142, 36, 170))
RADIUS = 56

def inside(x, y):
    near_x = min(x, SIZE - 1 - x)
    near_y = min(y, SIZE - 1 - y)
    if near_x >= RADIUS or near_y >= RADIUS:
        return True
    return (RADIUS - near_x) ** 2 + (RADIUS - near_y) ** 2 <= RADIUS ** 2

rows = bytearray()
for y in range(SIZE):
    rows.append(0)
    for x in range(SIZE):
        colour = COLOURS[(y >= SIZE // 2) * 2 + (x >= SIZE // 2)]
        hole = (x - SIZE / 2) ** 2 + (y - SIZE / 2) ** 2 < 46 ** 2
        rows.extend((255, 255, 255, 255) if hole else (*colour, 255 if inside(x, y) else 0))

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

target = Path(__file__).resolve().parents[1] / "hub" / "assets" / "gaaglu.png"
target.parent.mkdir(exist_ok=True)
target.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
