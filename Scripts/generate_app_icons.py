#!/usr/bin/env python3
"""Generate DoesTrack app icons using only the Python standard library."""

from __future__ import annotations

import math
import os
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "DoesTrack" / "Supporting" / "Assets.xcassets" / "AppIcon.appiconset"

SIZES = {
    "Icon-20@1x.png": 20,
    "Icon-20@2x.png": 40,
    "Icon-20@3x.png": 60,
    "Icon-29@1x.png": 29,
    "Icon-29@2x.png": 58,
    "Icon-29@3x.png": 87,
    "Icon-40@1x.png": 40,
    "Icon-40@2x.png": 80,
    "Icon-40@3x.png": 120,
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-76@1x.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
    "Icon-1024.png": 1024,
}


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    if edge0 == edge1:
        return 1.0 if x >= edge1 else 0.0
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def rounded_box_alpha(px: float, py: float, cx: float, cy: float, width: float, height: float, radius: float) -> float:
    qx = abs(px - cx) - width / 2 + radius
    qy = abs(py - cy) - height / 2 + radius
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    distance = outside + inside - radius
    return 1.0 - smoothstep(-1.2, 1.2, distance)


def capsule_alpha(px: float, py: float, cx: float, cy: float, width: float, height: float, angle: float) -> float:
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    dx = px - cx
    dy = py - cy
    x = dx * cos_a + dy * sin_a
    y = -dx * sin_a + dy * cos_a
    cap_radius = height / 2
    line_half = max(0.0, width / 2 - cap_radius)
    distance = math.hypot(max(abs(x) - line_half, 0.0), y) - cap_radius
    return 1.0 - smoothstep(-1.2, 1.2, distance)


def rotated_box_alpha(
    px: float,
    py: float,
    cx: float,
    cy: float,
    width: float,
    height: float,
    radius: float,
    angle: float,
) -> float:
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    dx = px - cx
    dy = py - cy
    x = dx * cos_a + dy * sin_a
    y = -dx * sin_a + dy * cos_a
    qx = abs(x) - width / 2 + radius
    qy = abs(y) - height / 2 + radius
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    distance = outside + inside - radius
    return 1.0 - smoothstep(-1.2, 1.2, distance)


def blend(base: tuple[int, int, int, int], overlay: tuple[int, int, int, int], alpha: float) -> tuple[int, int, int, int]:
    alpha = min(1.0, max(0.0, alpha)) * (overlay[3] / 255)
    inv = 1.0 - alpha
    return (
        round(base[0] * inv + overlay[0] * alpha),
        round(base[1] * inv + overlay[1] * alpha),
        round(base[2] * inv + overlay[2] * alpha),
        255,
    )


def draw(size: int) -> bytes:
    top = (23, 107, 135)
    bottom = (70, 170, 150)
    highlight = (255, 255, 255, 215)
    shadow = (8, 48, 66, 56)
    data = bytearray()

    for y in range(size):
        scanline = bytearray([0])
        for x in range(size):
            nx = (x + 0.5) / size
            ny = (y + 0.5) / size
            radial = math.hypot(nx - 0.28, ny - 0.18)
            gradient_t = min(1.0, max(0.0, ny * 0.85 + radial * 0.25))
            r, g, b = mix(top, bottom, gradient_t)
            pixel = (r, g, b, 255)

            # Soft lower-right depth.
            depth = smoothstep(0.25, 1.0, math.hypot(nx - 0.86, ny - 0.9))
            pixel = blend(pixel, (0, 38, 54, 255), depth * 0.18)

            # Calendar card.
            card_alpha = rounded_box_alpha(
                x + 0.5,
                y + 0.5,
                size * 0.5,
                size * 0.55,
                size * 0.58,
                size * 0.56,
                size * 0.075,
            )
            pixel = blend(pixel, shadow, card_alpha * 0.16)
            pixel = blend(pixel, highlight, card_alpha * 0.9)

            # Top binding strip.
            strip_alpha = rounded_box_alpha(
                x + 0.5,
                y + 0.5,
                size * 0.5,
                size * 0.36,
                size * 0.58,
                size * 0.12,
                size * 0.045,
            )
            pixel = blend(pixel, (243, 112, 89, 245), strip_alpha)

            # Two check dots.
            for dot_x, dot_y, dot_color in (
                (0.37, 0.55, (23, 107, 135, 235)),
                (0.37, 0.68, (70, 170, 150, 235)),
            ):
                distance = math.hypot((x + 0.5) - size * dot_x, (y + 0.5) - size * dot_y)
                dot_alpha = 1.0 - smoothstep(size * 0.027, size * 0.038, distance)
                pixel = blend(pixel, dot_color, dot_alpha)

            # Pill mark.
            pill_alpha = capsule_alpha(
                x + 0.5,
                y + 0.5,
                size * 0.58,
                size * 0.61,
                size * 0.28,
                size * 0.10,
                -0.58,
            )
            pixel = blend(pixel, (255, 255, 255, 255), pill_alpha)
            split_alpha = rotated_box_alpha(
                x + 0.5,
                y + 0.5,
                size * 0.58,
                size * 0.61,
                size * 0.016,
                size * 0.105,
                size * 0.006,
                -0.58,
            )
            pixel = blend(pixel, (23, 107, 135, 220), split_alpha)

            scanline.extend(pixel)
        data.extend(scanline)

    return png_bytes(size, size, bytes(data))


def png_bytes(width: int, height: int, raw: bytes) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    for filename, size in SIZES.items():
        (ICON_DIR / filename).write_bytes(draw(size))


if __name__ == "__main__":
    main()
