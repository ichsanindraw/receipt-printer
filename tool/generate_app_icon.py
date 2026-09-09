"""Draws the app icon from the app's own design tokens.

Run: python3 tool/generate_app_icon.py
Then: dart run flutter_launcher_icons

The mark is a receipt slip with a torn bottom edge and a map pin — the two
things the app does — in the palette from lib/theme/app_theme.dart.

The artwork is drawn on a transparent layer and then centred on its own
bounding box, so the margins stay even no matter how the shapes are tweaked.
"""

from PIL import Image, ImageDraw

SIZE = 1024        # final icon size
SS = 4             # supersample factor, downscaled at the end for clean edges
COVERAGE = 0.76    # how much of the canvas the artwork spans

INK = (23, 22, 20)          # AppColors.lightInk, the icon ground
PAPER = (244, 243, 240)     # AppColors.lightBackground
LINE = (198, 193, 185)      # muted rules on the slip
HEADING = (58, 54, 48)      # the slip's header block
AMBER = (238, 130, 45)      # the accent, brightened to carry on a dark ground

# Design-space geometry (arbitrary units; the result is scaled to fit).
SLIP = (60, 40, 470, 660)   # left, top, right, body bottom
TEETH_BOTTOM = 726
PIN = (500, 560, 122)       # centre x, centre y, radius


def draw_slip(draw, k):
    left, top, right, bottom = SLIP

    draw.rounded_rectangle(
        [left * k, top * k, right * k, bottom * k],
        radius=30 * k,
        fill=PAPER,
    )

    # Torn perforation along the bottom edge.
    teeth = 7
    width = (right - left) / teeth
    points = [(left * k, (bottom - 30) * k)]
    for i in range(teeth):
        points.append(((left + width * (i + 0.5)) * k, TEETH_BOTTOM * k))
        points.append(((left + width * (i + 1)) * k, (bottom - 30) * k))
    points.append((right * k, (bottom - 60) * k))
    points.append((left * k, (bottom - 60) * k))
    draw.polygon(points, fill=PAPER)

    # A header block, two rules, then the total in the accent colour.
    inset = 60
    x = left + inset
    draw.rounded_rectangle(
        [x * k, 150 * k, (right - inset) * k, 200 * k], radius=10 * k,
        fill=HEADING,
    )
    for y, w in ((248, 268), (316, 200)):
        draw.rounded_rectangle(
            [x * k, y * k, (x + w) * k, (y + 34) * k], radius=17 * k, fill=LINE
        )
    draw.rounded_rectangle(
        [x * k, 400 * k, (x + 150) * k, 452 * k], radius=20 * k, fill=AMBER
    )


def draw_pin(draw, k, cx, cy, r, colour):
    """A map pin: round head merged with a tapered tail."""
    draw.ellipse(
        [(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=colour
    )
    w = 0.72
    draw.polygon(
        [
            ((cx - r * w) * k, (cy + r * w * 0.98) * k),
            ((cx + r * w) * k, (cy + r * w * 0.98) * k),
            (cx * k, (cy + r * 2.05) * k),
        ],
        fill=colour,
    )


def draw_artwork(draw, k):
    cx, cy, r = PIN
    draw_slip(draw, k)
    # The pin sits straight on the slip. Its eye is paper-coloured rather than
    # knocked through, so it reads the same over the slip and over the ground.
    draw_pin(draw, k, cx, cy, r, AMBER)
    eye = r * 0.34
    draw.ellipse(
        [(cx - eye) * k, (cy - eye) * k, (cx + eye) * k, (cy + eye) * k],
        fill=PAPER,
    )


def render(background, coverage=COVERAGE):
    """background=None yields the transparent Android adaptive foreground."""
    k = SS  # design units are already close to final pixels

    layer = Image.new("RGBA", (900 * k, 900 * k), (0, 0, 0, 0))
    draw_artwork(ImageDraw.Draw(layer), k)

    art = layer.crop(layer.getbbox())
    target = int(SIZE * coverage)
    scale = target / max(art.width, art.height)
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )

    canvas = Image.new("RGBA", (SIZE, SIZE), (*background, 255) if background else (0, 0, 0, 0))
    canvas.paste(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2), art)
    return canvas


def main():
    render(INK).convert("RGB").save("assets/icon/app_icon.png")
    # flutter_launcher_icons wraps the adaptive foreground in a 16% inset
    # (a 0.68 scale), so this is drawn large to land near 58% of the final
    # 108dp canvas — inside Android's 66% safe zone.
    render(None, coverage=0.85).save("assets/icon/app_icon_foreground.png")
    print("wrote assets/icon/app_icon.png and app_icon_foreground.png")


if __name__ == "__main__":
    main()
