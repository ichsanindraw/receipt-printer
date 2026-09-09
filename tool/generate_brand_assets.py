"""Draws the app icon and splash artwork from the app's own design tokens.

Run: python3 tool/generate_brand_assets.py
Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create

The mark is a receipt slip with a torn bottom edge and a map pin — the two
things the app does — in the palette from lib/theme/app_theme.dart. It is
drawn twice: light-on-dark for the icon and the dark splash, dark-on-light
for the light splash, so it reads on either ground.

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

DARK_GROUND = (18, 17, 16)  # AppColors.darkBackground, the dark splash ground

# The slip inverts so the mark keeps its contrast on either ground. The pin
# and its eye stay put: amber and paper read against both.
ON_DARK = {"slip": PAPER, "heading": HEADING, "line": LINE}
ON_LIGHT = {"slip": INK, "heading": PAPER, "line": (122, 116, 107)}

# Design-space geometry (arbitrary units; the result is scaled to fit).
SLIP = (60, 40, 470, 660)   # left, top, right, body bottom
TEETH_BOTTOM = 726
PIN = (500, 560, 122)       # centre x, centre y, radius


def draw_slip(draw, k, palette):
    left, top, right, bottom = SLIP

    draw.rounded_rectangle(
        [left * k, top * k, right * k, bottom * k],
        radius=30 * k,
        fill=palette["slip"],
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
    draw.polygon(points, fill=palette["slip"])

    # A header block, two rules, then the total in the accent colour.
    inset = 60
    x = left + inset
    draw.rounded_rectangle(
        [x * k, 150 * k, (right - inset) * k, 200 * k], radius=10 * k,
        fill=palette["heading"],
    )
    for y, w in ((248, 268), (316, 200)):
        draw.rounded_rectangle(
            [x * k, y * k, (x + w) * k, (y + 34) * k], radius=17 * k, fill=palette["line"]
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


def draw_artwork(draw, k, palette):
    cx, cy, r = PIN
    draw_slip(draw, k, palette)
    # The pin sits straight on the slip. Its eye is paper-coloured rather than
    # knocked through, so it reads the same over the slip and over the ground.
    draw_pin(draw, k, cx, cy, r, AMBER)
    eye = r * 0.34
    draw.ellipse(
        [(cx - eye) * k, (cy - eye) * k, (cx + eye) * k, (cy + eye) * k],
        fill=PAPER,
    )


def render(background, palette=ON_DARK, coverage=COVERAGE, size=SIZE):
    """background=None yields a transparent layer (adaptive icon, splash)."""
    k = SS  # design units are already close to final pixels

    layer = Image.new("RGBA", (900 * k, 900 * k), (0, 0, 0, 0))
    draw_artwork(ImageDraw.Draw(layer), k, palette)

    art = layer.crop(layer.getbbox())
    target = int(size * coverage)
    scale = target / max(art.width, art.height)
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )

    canvas = Image.new(
        "RGBA", (size, size), (*background, 255) if background else (0, 0, 0, 0)
    )
    canvas.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    return canvas


def main():
    render(INK).convert("RGB").save("assets/icon/app_icon.png")
    # flutter_launcher_icons wraps the adaptive foreground in a 16% inset
    # (a 0.68 scale), so this is drawn large to land near 58% of the final
    # 108dp canvas — inside Android's 66% safe zone.
    render(None, coverage=0.85).save("assets/icon/app_icon_foreground.png")

    # Splash art is transparent; flutter_native_splash paints the ground.
    # It treats the source as the 4x asset, so 640px lands a ~145dp logo at
    # mdpi — a 1024px source would render it around 205dp, far too large.
    render(None, ON_LIGHT, coverage=0.92, size=640).save(
        "assets/splash/splash_light.png"
    )
    render(None, ON_DARK, coverage=0.92, size=640).save(
        "assets/splash/splash_dark.png"
    )

    # Android 12+ draws the splash icon inside a 768px circle on a 1152px
    # canvas, so the mark is sized to that rather than to the full square.
    for name, palette in (("light", ON_LIGHT), ("dark", ON_DARK)):
        render(None, palette, coverage=768 / 1152, size=1152).save(
            f"assets/splash/splash_android12_{name}.png"
        )

    print("wrote assets/icon/*.png and assets/splash/*.png")


if __name__ == "__main__":
    main()
