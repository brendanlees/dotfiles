#!/usr/bin/env python3
"""Print a SketchyBar ARGB color sampled from a Spotify artwork URL.

Uses only macOS built-ins plus Python stdlib: downloads artwork, asks `sips`
to downsample it to a tiny BMP, then chooses a vivid readable pixel.
Failures are silent so the caller can fall back to the theme color.
"""

from __future__ import annotations

import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path


def fail() -> None:
    sys.exit(0)


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "sketchybar-spotify"})
    with urllib.request.urlopen(request, timeout=2) as response:
        data = response.read(2_000_000)
    if not data:
        raise RuntimeError("empty artwork")
    dest.write_bytes(data)


def parse_bmp_pixels(path: Path) -> list[tuple[int, int, int]]:
    data = path.read_bytes()
    if data[:2] != b"BM" or len(data) < 54:
        raise RuntimeError("not bmp")

    offset = struct.unpack_from("<I", data, 10)[0]
    width = struct.unpack_from("<i", data, 18)[0]
    height = struct.unpack_from("<i", data, 22)[0]
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp not in (24, 32) or width == 0 or height == 0:
        raise RuntimeError("unsupported bmp")

    width_abs = abs(width)
    height_abs = abs(height)
    bytes_per_pixel = bpp // 8
    row_stride = ((width_abs * bytes_per_pixel + 3) // 4) * 4
    pixels: list[tuple[int, int, int]] = []

    for y in range(height_abs):
        row_start = offset + y * row_stride
        for x in range(width_abs):
            i = row_start + x * bytes_per_pixel
            if i + 2 >= len(data):
                continue
            b, g, r = data[i], data[i + 1], data[i + 2]
            pixels.append((r, g, b))
    return pixels


def luminance(r: int, g: int, b: int) -> float:
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def saturation(r: int, g: int, b: int) -> float:
    hi = max(r, g, b)
    lo = min(r, g, b)
    return 0.0 if hi == 0 else (hi - lo) / hi


def lift_if_dark(r: int, g: int, b: int) -> tuple[int, int, int]:
    lum = luminance(r, g, b)
    if lum >= 0.36:
        return r, g, b
    # Mix with white enough to show as a border on dark pills.
    mix = min(0.45, 0.36 - lum + 0.18)
    return tuple(round(c * (1 - mix) + 255 * mix) for c in (r, g, b))  # type: ignore[return-value]


def choose_color(pixels: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    candidates = []
    for r, g, b in pixels:
        lum = luminance(r, g, b)
        sat = saturation(r, g, b)
        if 0.18 <= lum <= 0.92 and sat >= 0.12:
            score = sat * 0.72 + lum * 0.28
            candidates.append((score, r, g, b))
    if candidates:
        _, r, g, b = max(candidates)
        return lift_if_dark(r, g, b)

    if pixels:
        r = round(sum(p[0] for p in pixels) / len(pixels))
        g = round(sum(p[1] for p in pixels) / len(pixels))
        b = round(sum(p[2] for p in pixels) / len(pixels))
        return lift_if_dark(r, g, b)

    raise RuntimeError("no pixels")


def main() -> None:
    if len(sys.argv) < 2 or not sys.argv[1].startswith(("http://", "https://")):
        fail()

    url = sys.argv[1]
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sketchybar" / "spotify-art"
    cache_dir.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha1(url.encode("utf-8")).hexdigest()
    artwork = cache_dir / f"{key}.art"
    bmp = cache_dir / f"{key}.bmp"

    try:
        if not artwork.exists():
            download(url, artwork)
        if not bmp.exists():
            with tempfile.NamedTemporaryFile(suffix=".bmp", delete=False) as tmp:
                tmp_path = Path(tmp.name)
            try:
                subprocess.run(
                    ["/usr/bin/sips", "-z", "8", "8", "-s", "format", "bmp", str(artwork), "--out", str(tmp_path)],
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=2,
                )
                tmp_path.replace(bmp)
            finally:
                tmp_path.unlink(missing_ok=True)
        r, g, b = choose_color(parse_bmp_pixels(bmp))
    except Exception:
        fail()

    print(f"0xff{r:02x}{g:02x}{b:02x}")


if __name__ == "__main__":
    main()
