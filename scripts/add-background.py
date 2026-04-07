#!/usr/bin/env python3
"""
Description : Composite a window screenshot (containing transparent borders) over a
              mirrored/rotated version of a background image (images/_background.png).
              Produces <name>-bg.png next to the input file.
Usage       : python3 scripts/add-background.py images/Preferences-General.png [more files...]
Requires    : Pillow (pip3 install Pillow)
"""

import random
import sys
from pathlib import Path

from PIL import Image


def find_background() -> Path:
    """Locate images/_background.png relative to the repo root."""
    bg = Path(__file__).resolve().parent.parent / "images" / "_background.png"
    if not bg.exists():
        sys.exit(f"Background not found: {bg}")
    return bg


def random_transform(img: Image.Image) -> Image.Image:
    """Rotate by a random multiple of 90° and optionally mirror."""
    angle = random.choice([0, 90, 180, 270])
    if angle:
        img = img.rotate(angle, expand=True)
    if random.random() < 0.5:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def cover_crop(bg: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Scale bg to cover target dimensions (no distortion), then center-crop."""
    bg_w, bg_h = bg.size
    scale = max(target_w / bg_w, target_h / bg_h)
    new_w = round(bg_w * scale)
    new_h = round(bg_h * scale)
    bg = bg.resize((new_w, new_h), Image.LANCZOS)

    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    return bg.crop((left, top, left + target_w, top + target_h))


def output_path(input_path: Path) -> Path:
    """Build output path, stripping existing -bg suffix to avoid foo-bg-bg.png."""
    stem = input_path.stem
    if stem.endswith("-bg"):
        stem = stem[:-3]
    return input_path.with_name(f"{stem}-bg.png")


def process_file(input_path: Path, bg_path: Path) -> None:
    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return

    screenshot = Image.open(input_path).convert("RGBA")
    bg = Image.open(bg_path).convert("RGBA")

    bg = random_transform(bg)
    bg = cover_crop(bg, screenshot.width, screenshot.height)

    bg.paste(screenshot, (0, 0), screenshot)

    result_w = round(bg.width * 0.67)
    result_h = round(bg.height * 0.67)
    bg = bg.resize((result_w, result_h), Image.LANCZOS)

    out = output_path(input_path)
    bg.save(out, "PNG")
    print(f"Saved: {out}")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(f"Usage: {sys.argv[0]} <screenshot.png> [more files...]")

    bg_path = find_background()
    for arg in sys.argv[1:]:
        process_file(Path(arg), bg_path)


if __name__ == "__main__":
    main()
