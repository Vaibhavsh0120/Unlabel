"""Rebuild owned Unlabel brand assets with Pillow/fontTools; check is stdlib only.

PNG assets are committed, so normal setup/build never needs Pillow. The editable
SVGs and generated platform assets share the same simple vector geometry here.
"""

# Pillow/fontTools are optional authoring dependencies, not needed for --check.
# pyright: reportMissingImports=false

import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "frontend/assets/brand"
MANIFEST = BRAND / "icon-manifest.json"
LIGHT = ("#FFFFFF", "#123D32", "#0D5540", "#69BA90")
DARK = ("#131719", "#EAF9F1", "#2DAD78", "#A1F1C4")
FONT = BRAND / "fonts/Nunito-Variable.ttf"
LEAF_PATH = "M348 612 C265 392 419 226 728 218 C736 474 602 640 394 630 Z"
VEIN_PATH = "M338 662 C397 543 496 426 645 320"
WORDMARK_SIZE = 154
WORDMARK_BASELINE = 796


def wordmark_path():
    """Outline the licensed rounded wordmark, so native assets need no font SDK."""
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    with TTFont(FONT) as font:
        glyphs = font.getGlyphSet(location={"wght": 800})
        cmap = font.getBestCmap()
        scale = WORDMARK_SIZE / font["head"].unitsPerEm
        names = [cmap[ord(letter)] for letter in "Unlabel"]
        width = sum(glyphs[name].width for name in names) * scale
        cursor = (1024 - width) / 2
        pen = SVGPathPen(
            glyphs, ntos=lambda number: f"{number:.3f}".rstrip("0").rstrip(".")
        )
        for name in names:
            glyphs[name].draw(
                TransformPen(pen, (scale, 0, 0, -scale, cursor, WORDMARK_BASELINE))
            )
            cursor += glyphs[name].width * scale
        return pen.getCommands()


def svg(colors, wordmark, transparent=False):
    background, ink, leaf_start, leaf_end = colors
    fill = "" if transparent else f'<path fill="{background}" d="M0 0H1024V1024H0Z"/>'
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        "<title>Unlabel leaf and rounded wordmark</title>"
        '<defs><linearGradient id="leaf" x1="300" y1="650" x2="740" y2="200" gradientUnits="userSpaceOnUse">'
        f'<stop stop-color="{leaf_start}"/><stop offset="1" stop-color="{leaf_end}"/></linearGradient>'
        '<mask id="leaf-cutout"><path fill="white" d="M0 0H1024V1024H0Z"/>'
        f'<path d="{VEIN_PATH}" fill="none" stroke="black" stroke-width="17" stroke-linecap="round"/></mask></defs>'
        f'{fill}<path d="{LEAF_PATH}" fill="url(#leaf)" mask="url(#leaf-cutout)"/>'
        f'<path d="{wordmark}" fill="{ink}"/></svg>\n'
    )


def bezier(start, a, b, end):
    return [
        tuple(
            (1 - t) ** 3 * start[k]
            + 3 * (1 - t) ** 2 * t * a[k]
            + 3 * (1 - t) * t * t * b[k]
            + t**3 * end[k]
            for k in range(2)
        )
        for t in [i / 100 for i in range(101)]
    ]


def draw_icon(colors, transparent=False):
    from PIL import Image, ImageDraw, ImageFont

    scale = 3
    background, ink, leaf_start, leaf_end = colors
    canvas = Image.new(
        "RGBA",
        (1024 * scale, 1024 * scale),
        (0, 0, 0, 0) if transparent else background,
    )

    def points(values):
        return [(round(x * scale), round(y * scale)) for x, y in values]

    shape = bezier((348, 612), (265, 392), (419, 226), (728, 218))
    shape += bezier((728, 218), (736, 474), (602, 640), (394, 630))
    mask = Image.new("L", canvas.size)
    ImageDraw.Draw(mask).polygon(points(shape), fill=255)
    # Project onto the same diagonal as the editable SVG's linear gradient.
    start = tuple(bytes.fromhex(leaf_start[1:]))
    end = tuple(bytes.fromhex(leaf_end[1:]))
    small_gradient = Image.new("RGB", (1024, 1024))
    pixels = small_gradient.load()
    for y in range(1024):
        for x in range(1024):
            t = max(0, min(1, ((x - 300) * 440 - (y - 650) * 450) / 396100))
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(start, end, strict=True))
    gradient = small_gradient.resize(canvas.size, Image.Resampling.BILINEAR)
    canvas.paste(gradient, (0, 0), mask)
    draw = ImageDraw.Draw(canvas)
    vein = bezier((338, 662), (397, 543), (496, 426), (645, 320))
    cutout = (0, 0, 0, 0) if transparent else background
    draw.line(points(vein), fill=cutout, width=17 * scale, joint="curve")
    for x, y in [vein[0], vein[-1]]:
        draw.ellipse(
            (
                (x - 8.5) * scale,
                (y - 8.5) * scale,
                (x + 8.5) * scale,
                (y + 8.5) * scale,
            ),
            fill=cutout,
        )
    font = ImageFont.truetype(FONT, WORDMARK_SIZE * scale)
    font.set_variation_by_axes([800])
    draw.text(
        (512 * scale, WORDMARK_BASELINE * scale),
        "Unlabel",
        font=font,
        fill=ink,
        anchor="ms",
    )
    return canvas.resize((1024, 1024), Image.Resampling.LANCZOS)


def generate():
    from PIL import Image

    BRAND.mkdir(parents=True, exist_ok=True)
    files = []

    def write(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data if isinstance(data, bytes) else data.encode("utf-8"))
        files.append(path)

    def png(path, image, size, alpha=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        image.resize((size, size), Image.Resampling.LANCZOS).convert(
            "RGBA" if alpha else "RGB"
        ).save(path, optimize=True)
        files.append(path)

    wordmark = wordmark_path()
    light, dark = draw_icon(LIGHT), draw_icon(DARK)
    for mode, colors, image in [("light", LIGHT, light), ("dark", DARK, dark)]:
        write(BRAND / f"app-icon-{mode}.svg", svg(colors, wordmark))
        png(BRAND / f"app-icon-{mode}.png", image, 1024)
    ios = ROOT / "frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    # Single-size assets support older systems; iOS18+ selects the dark appearance.
    for stale in ios.glob("Icon-App-*.png"):
        stale.unlink()
    png(ios / "AppIcon-Light.png", light, 1024)
    png(ios / "AppIcon-Dark.png", draw_icon(DARK, transparent=True), 1024, alpha=True)
    write(
        ios / "Contents.json",
        json.dumps(
            {
                "images": [
                    {
                        "filename": "AppIcon-Light.png",
                        "idiom": "universal",
                        "platform": "ios",
                        "size": "1024x1024",
                    },
                    {
                        "filename": "AppIcon-Dark.png",
                        "idiom": "universal",
                        "platform": "ios",
                        "size": "1024x1024",
                        "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    },
                ],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n",
    )
    android = ROOT / "frontend/android/app/src/main/res"
    for density, size in [
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ]:
        png(android / f"mipmap-{density}/ic_launcher.png", light, size)
        png(android / f"mipmap-night-{density}/ic_launcher.png", dark, size)
    # Foreground occupies the adaptive safe zone (centered in a108dp viewport).
    path = (
        f'<path android:pathData="{LEAF_PATH}"><aapt:attr name="android:fillColor">'
        '<gradient android:type="linear" android:startX="300" android:startY="650" android:endX="740" android:endY="200">'
        '<item android:offset="0" android:color="@color/icon_leaf_start"/><item android:offset="1" android:color="@color/icon_leaf_end"/>'
        "</gradient></aapt:attr></path>"
    )
    vector = (
        '<vector xmlns:android="http://schemas.android.com/apk/res/android" xmlns:aapt="http://schemas.android.com/aapt" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024"><group android:scaleX="0.72" android:scaleY="0.72" android:pivotX="512" android:pivotY="512">'
        f'{path}<path android:pathData="{VEIN_PATH}" android:fillColor="@android:color/transparent" android:strokeColor="@color/icon_background" android:strokeWidth="17" android:strokeLineCap="round"/>'
        f'<path android:pathData="{wordmark}" android:fillColor="@color/icon_ink"/></group></vector>\n'
    )
    write(android / "drawable/ic_launcher_foreground.xml", vector)
    write(
        android / "drawable/ic_launcher_monochrome.xml",
        '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024"><group android:scaleX="0.72" android:scaleY="0.72" android:pivotX="512" android:pivotY="512">'
        f'<path android:pathData="{LEAF_PATH}" android:fillColor="#FFFFFFFF"/><path android:pathData="{wordmark}" android:fillColor="#FFFFFFFF"/></group></vector>\n',
    )
    for qualifier, colors in [("values", LIGHT), ("values-night", DARK)]:
        write(
            android / f"{qualifier}/icon_colors.xml",
            f'<resources><color name="icon_background">{colors[0]}</color><color name="icon_ink">{colors[1]}</color><color name="icon_leaf_start">{colors[2]}</color><color name="icon_leaf_end">{colors[3]}</color></resources>\n',
        )
    for version, mono in [
        (26, ""),
        (33, '<monochrome android:drawable="@drawable/ic_launcher_monochrome"/>'),
    ]:
        write(
            android / f"mipmap-anydpi-v{version}/ic_launcher.xml",
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/icon_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/>'
            + mono
            + "</adaptive-icon>\n",
        )
    web = ROOT / "frontend/web"
    for mode, image in [("light", light), ("dark", dark)]:
        png(web / f"favicon-{mode}.png", image, 32)
        for size in [192, 512]:
            png(web / f"icons/Icon-{mode}-{size}.png", image, size)
            png(web / f"icons/Icon-maskable-{mode}-{size}.png", image, size)
        png(web / f"icons/apple-touch-{mode}.png", image, 180)
    # Stable fallback names preserve older bookmarks/manifests.
    png(web / "favicon.png", light, 32)
    for size in [192, 512]:
        png(web / f"icons/Icon-{size}.png", light, size)
        png(web / f"icons/Icon-maskable-{size}.png", light, size)
    files.extend([FONT, FONT.parent / "OFL.txt"])
    records = []
    for path in files:
        data = path.read_bytes()
        record = {
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": hashlib.sha256(data).hexdigest(),
        }
        if path.suffix == ".png":
            record["size"] = list(struct.unpack(">II", data[16:24]))
        records.append(record)
    MANIFEST.write_text(
        json.dumps(
            {
                "version": "unlabel-leaf-wordmark-v2",
                "default": "light",
                "files": records,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def check():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        path = ROOT / entry["path"]
        if not path.resolve().is_relative_to(ROOT) or not path.is_file():
            raise ValueError("Missing or escaping icon path")
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"Icon changed without regeneration: {entry['path']}")
        if "size" in entry and list(struct.unpack(">II", data[16:24])) != entry["size"]:
            raise ValueError("Incorrect icon dimensions")
    print(
        f"Verified {len(manifest['files'])} brand/platform icon assets; default light."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        generate()
    check()
