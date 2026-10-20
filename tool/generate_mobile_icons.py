"""Generate iOS and Android launcher PNGs from the supplied rounded artwork.

Requires Pillow. Run with --source PATH to replace the saved source artwork.
"""

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tool/assets/mobile_icon.png"
RESAMPLE = Image.Resampling.LANCZOS


def square_artwork(source):
    """Extend the backdrop and remove the supplied rounded edge highlight."""
    image = source.convert("RGBA")
    width, height = image.size
    if width != height:
        raise ValueError("The source icon must be square")
    backdrop = Image.new("RGB", image.size)
    pixels = image.load()
    draw = ImageDraw.Draw(backdrop)
    inset = max(1, round(width * 0.012))
    for y in range(height):
        sample_y = min(max(y, inset), height - inset - 1)
        left = next(x for x in range(width) if pixels[x, sample_y][3] == 255)
        color = pixels[min(left + inset, width // 2), sample_y][:3]
        draw.line((0, y, width, y), fill=color)
    mask = Image.new("L", image.size)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, width - inset - 1, height - inset - 1),
        radius=round(width * 0.20),
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(width * 0.003))
    return Image.composite(image.convert("RGB"), backdrop, mask)


def adaptive_artwork(master):
    # Android exposes the middle 72dp of a 108dp layer; keep the logo inside it.
    size = 1296
    content_size = 864
    offset = (size - content_size) // 2
    content = master.resize((content_size, content_size), RESAMPLE)
    canvas = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(canvas)
    for y in range(size):
        sample_y = min(max(y - offset, 0), content_size - 1)
        draw.line((0, y, size, y), fill=content.getpixel((0, sample_y)))
    canvas.paste(content, (offset, offset))
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    if args.source:
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        if args.source.resolve() != SOURCE.resolve():
            shutil.copyfile(args.source, SOURCE)

    master = square_artwork(Image.open(SOURCE))
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    catalog = json.loads((ios / "Contents.json").read_text())
    for entry in catalog["images"]:
        size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
        master.resize((size, size), RESAMPLE).save(ios / entry["filename"])

    adaptive = adaptive_artwork(master)
    res = ROOT / "android/app/src/main/res"
    for density, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                           ("xxhdpi", 3), ("xxxhdpi", 4)]:
        folder = res / f"mipmap-{density}"
        size = round(48 * scale)
        master.resize((size, size), RESAMPLE).save(folder / "ic_launcher.png")
        mask = Image.new("L", master.size)
        ImageDraw.Draw(mask).ellipse((0, 0, master.width - 1, master.height - 1), fill=255)
        rounded = master.convert("RGBA")
        rounded.putalpha(mask)
        rounded.resize((size, size), RESAMPLE).save(folder / "ic_launcher_round.png")
        size = round(108 * scale)
        adaptive.resize((size, size), RESAMPLE).save(folder / "ic_launcher_foreground.png")
    print("Generated iOS AppIcon catalog and Android launcher icons at all densities.")


if __name__ == "__main__":
    main()
