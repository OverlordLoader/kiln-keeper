#!/usr/bin/env python3
"""Generate the Kiln Keeper app icon set into Assets.xcassets/AppIcon.appiconset.

Procedural kiln icon: dark cozy background, brick kiln arch with a glowing
fire mouth, and a small glass orb resting on top.
"""
from PIL import Image, ImageDraw
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "KilnKeeper" / "Assets.xcassets" / "AppIcon.appiconset"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Background: deep warm charcoal gradient.
    top, bottom = (26, 18, 30), (12, 8, 14)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, y / size) + (255,))

    cx = size // 2
    # Kiln arch body (brick).
    kw, kh = int(size * 0.62), int(size * 0.52)
    kx0, ky0 = cx - kw // 2, int(size * 0.34)
    brick, mortar = (122, 58, 34), (70, 32, 20)
    # Arch = rect + semicircle top.
    d.rectangle([kx0, ky0 + kw // 2, kx0 + kw, ky0 + kh], fill=brick)
    d.pieslice([kx0, ky0, kx0 + kw, ky0 + kw], start=180, end=360, fill=brick)
    # Brick courses.
    for i, yy in enumerate(range(ky0 + kw // 2, ky0 + kh, max(6, size // 40))):
        d.line([(kx0 + 4, yy), (kx0 + kw - 4, yy)], fill=mortar, width=max(2, size // 200))
        off = (i % 2) * kw // 8
        for xx in range(kx0 + off, kx0 + kw, kw // 4):
            d.line([(xx, yy - max(6, size // 40)), (xx, yy)], fill=mortar, width=max(2, size // 200))
    # Top highlight.
    d.arc([kx0 + 8, ky0 + 8, kx0 + kw - 8, ky0 + kw - 8], start=200, end=340,
          fill=(255, 200, 150, 90), width=max(3, size // 90))

    # Fire mouth: dark opening with radial fire glow.
    mw, mh = int(kw * 0.58), int(kh * 0.34)
    mx0, my0 = cx - mw // 2, ky0 + kh - mh - int(size * 0.05)
    d.rounded_rectangle([mx0, my0, mx0 + mw, my0 + mh], radius=mh // 2, fill=(8, 4, 4))
    for r in range(mh // 2, 0, -1):
        t = r / (mh // 2)
        col = lerp((255, 240, 200), (255, 110, 20), t)
        d.ellipse([cx - r, my0 + mh - r - 4, cx + r, my0 + mh + r - 4],
                  fill=col + (255,))
    # Flame tongues.
    for fx, fh in [(-0.16, 0.10), (0.0, 0.16), (0.16, 0.09)]:
        fx0 = int(cx + fx * mw)
        fy1 = my0 + mh - int(fh * size) - 6
        d.ellipse([fx0 - 9, fy1, fx0 + 9, my0 + mh], fill=(255, 180, 60, 230))

    # Glass orb resting on the kiln.
    orad = int(size * 0.085)
    oy = ky0 - orad - 4
    for r in range(orad, 0, -1):
        t = r / orad
        col = lerp((120, 200, 255), (30, 110, 180), t)
        d.ellipse([cx - r, oy - r, cx + r, oy + r], fill=col + (255,))
    d.ellipse([cx - orad // 2, oy - orad // 2 - 4, cx - orad // 6, oy - orad // 6],
              fill=(255, 255, 255, 200))
    # Warm glow behind everything.
    # (drawn as a soft ellipse behind the kiln via alpha composite)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(int(size * 0.45), 0, -4):
        a = int(60 * (1 - r / (size * 0.45)))
        gd.ellipse([cx - r, ky0 + kh // 2 - r, cx + r, ky0 + kh // 2 + r],
                   fill=(255, 120, 30, max(a, 0)))
    img = Image.alpha_composite(glow, img)

    # Rounded mask.
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size, size], radius=int(size * 0.225), fill=255)
    img.putalpha(mask)
    bg = Image.new("RGBA", (size, size), (12, 8, 14, 255))
    bg.paste(img, (0, 0), img)
    return bg.convert("RGB")


SIZES = [
    ("Icon-20@2x.png", 40, "20x20", "2x"),
    ("Icon-20@3x.png", 60, "20x20", "3x"),
    ("Icon-29@2x.png", 58, "29x29", "2x"),
    ("Icon-29@3x.png", 87, "29x29", "3x"),
    ("Icon-40@2x.png", 80, "40x40", "2x"),
    ("Icon-40@3x.png", 120, "40x40", "3x"),
    ("Icon-60@2x.png", 120, "60x60", "2x"),
    ("Icon-60@3x.png", 180, "60x60", "3x"),
    ("Icon-1024.png", 1024, "1024x1024", "1x"),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw_icon(1024)
    images = []
    for filename, px, size_str, scale in SIZES:
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(OUT / filename)
        images.append({"filename": filename, "idiom": "iphone",
                       "scale": scale, "size": size_str})
    (OUT / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print("wrote", len(images), "icons")


if __name__ == "__main__":
    main()
