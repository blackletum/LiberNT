#!/usr/bin/env python3
# PROJECT:     LiberNT user32
# LICENSE:     GPL-3.0-or-later (https://spdx.org/licenses/GPL-3.0-or-later)
# PURPOSE:     Build the system cursors from the Fluent white SVG cursors at every Windows cursor size
# COPYRIGHT:   Copyright 2026 Ahmed ARIF <arif.ing@outlook.com>

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

CANVAS = 32
GLYPHS = {32: 32, 40: 40, 48: 48, 56: 56, 64: 64, 72: 72, 80: 80, 96: 96, 128: 128}
COLORS = {}
ANIMATED_SIZES = (32, 40, 48, 56, 64, 72, 80, 96, 128)
JIFFIES = 2
CURSORS = (
    ("ocr_normal.cur", "default", (4, 4)),
    ("ocr_ibeam.cur", "text", (16, 16)),
    ("ocr_wait.ani", "wait", (16, 16)),
    ("ocr_cross.cur", "crosshair", (16, 16)),
    ("ocr_up.cur", "up-arrow", (16, 4)),
    ("ocr_sizenwse.cur", "size_fdiag", (16, 16)),
    ("ocr_sizenesw.cur", "size_bdiag", (16, 16)),
    ("ocr_sizewe.cur", "size_hor", (16, 16)),
    ("ocr_sizens.cur", "size_ver", (16, 16)),
    ("ocr_sizeall.cur", "fleur", (16, 16)),
    ("ocr_size.cur", "fleur", (16, 16)),
    ("ocr_no.cur", "not-allowed", (16, 16)),
    ("ocr_appstarting.ani", "progress", (4, 4)),
    ("ocr_help.cur", "help", (4, 4)),
    ("ocr_pen.cur", "pencil", (4, 29)),
    ("ocr_hand.cur", "pointer", (12, 4)),
    ("ocr_icon.cur", "default", (4, 4)),
    ("ocr_cdautostart.cur", "default", (4, 4)),
)


def read_png(path):
    data = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, colortype = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length
    if depth != 8 or colortype != 6:
        raise ValueError("%s: expected 8-bit RGBA" % path)
    stride = width * 4
    raw = zlib.decompress(idat)
    prev, rows, offset = bytearray(stride), [], 0
    for _ in range(height):
        kind, line = raw[offset], bytearray(raw[offset + 1:offset + 1 + stride])
        offset += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    return width, height, rows


def write_png(width, height, rows):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    raw = b"".join(b"\0" + row for row in rows)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def render(svg, size, work):
    glyph = GLYPHS[size]
    text = open(svg, encoding="utf-8").read()
    for match, replace in COLORS.items():
        text = re.sub(re.escape(match), replace, text, flags=re.IGNORECASE)
    tag = re.search(r"<svg\b[^>]*>", text)
    head = re.sub(r'\b(width|height)="[^"]*"', lambda m: '%s="%d"' % (m.group(1), glyph), tag.group(0))
    if "viewBox" not in head:
        head = head.replace("<svg", '<svg viewBox="0 0 %d %d"' % (CANVAS, CANVAS), 1)
    scaled = os.path.join(work, "scaled.svg")
    target = os.path.join(work, "scaled.png")
    open(scaled, "w", encoding="utf-8").write(text[:tag.start()] + head + text[tag.end():])
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", str(glyph), "-h", str(glyph), "-o", target, scaled], check=True)
    else:
        subprocess.run(["sips", "-s", "format", "png", scaled, "--out", target], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    width, height, rows = read_png(target)
    if (width, height) != (glyph, glyph):
        raise ValueError("%s rendered at %dx%d instead of %d" % (svg, width, height, glyph))
    canvas = [row + bytes(4 * (size - glyph)) for row in rows] + [bytes(4 * size)] * (size - glyph)
    return write_png(size, size, canvas)


def cursor_file(svg, hotspot, work, sizes=None):
    images = [(size, int(hotspot[0] * GLYPHS[size] / CANVAS), int(hotspot[1] * GLYPHS[size] / CANVAS),
               render(svg, size, work)) for size in (sizes or sorted(GLYPHS))]
    out = struct.pack("<HHH", 0, 2, len(images))
    offset = 6 + 16 * len(images)
    for size, x, y, png in images:
        out += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, x, y, len(png), offset)
        offset += len(png)
    return out + b"".join(png for _, _, _, png in images)


def riff_chunk(kind, body):
    return kind + struct.pack("<I", len(body)) + body + (b"\0" if len(body) & 1 else b"")


def animated_file(paths, hotspot, work):
    frames = b"".join(riff_chunk(b"icon", cursor_file(path, hotspot, work, ANIMATED_SIZES)) for path in paths)
    header = struct.pack("<9I", 36, len(paths), len(paths), 0, 0, 0, 0, JIFFIES, 1)
    body = b"ACON" + riff_chunk(b"anih", header) + riff_chunk(b"LIST", b"fram" + frames)
    return b"RIFF" + struct.pack("<I", len(body)) + body


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: curgen.py <Fluent cursor svg folder> <output folder>")
    source, target = sys.argv[1], sys.argv[2]
    work = tempfile.mkdtemp()
    try:
        for name, svgname, hotspot in CURSORS:
            if name.endswith(".ani"):
                folder = os.path.join(source, svgname)
                frames = sorted(os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".svg"))
                data = animated_file(frames, hotspot, work)
            else:
                data = cursor_file(os.path.join(source, svgname + ".svg"), hotspot, work)
            open(os.path.join(target, name), "wb").write(data)
            print("%s <- %s (%d bytes)" % (name, svgname, len(data)))
    finally:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
