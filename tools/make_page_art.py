"""make_page_art.py - builds the pictures used AROUND the game: the itch page's
banner and background, and the YouTube thumbnail for the trailer.

WHY: all three are cut from the same key art as the title screen and the itch
cover (see make_cover.py), with the logo in the game's own marker font, so the
page, the video and the game look like one thing. Re-run it if the art changes.

USE (from the project folder):   python tools/make_page_art.py
OUT:   itch/page_banner_960x300.png          itch "Banner"
       itch/page_background_1920x1080.jpg    itch "Background"
       itch/youtube_thumbnail_1280x720.jpg   YouTube thumbnail (16:9, under 2 MB)
       itch/youtube_thumbnail_preview_320.jpg  the same at phone-list size, to
                                               check the words still read

Needs the Pillow library (pip install pillow).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent  # the project folder (one above tools/)
KEY_ART = ROOT / "art" / "sprites" / "title_art.jpg"
FONT = str(ROOT / "art" / "fonts" / "PermanentMarker-Regular.ttf")
OUT_DIR = ROOT / "itch"

TEAL = (89, 230, 217)    # the title screen's logo colour
AMBER = (255, 209, 128)  # Canopy FM's text colour
NIGHT = (10, 13, 18)     # near-black, for outlines
TAGLINE = "Helios owns the sun. Your block stopped paying for it."


def make_banner(art: Image.Image) -> None:
    """A wide strip of the art, darkened, with the logo and the tagline."""
    width, height = 960, 300
    wide = art.resize((width, round(art.height * width / art.width)), Image.LANCZOS)
    top = round(wide.height * 0.30)  # start a third of the way down: the alley, not the sky
    banner = ImageEnhance.Brightness(wide.crop((0, top, width, top + height))).enhance(0.55)
    draw = ImageDraw.Draw(banner)
    # anchor="mm" means the given point is the MIDDLE of the text, both ways.
    draw.text((width / 2, height * 0.44), "SEEDSHOT", font=ImageFont.truetype(FONT, 124), fill=TEAL,
              anchor="mm", stroke_width=6, stroke_fill=NIGHT)
    draw.text((width / 2, height * 0.80), TAGLINE, font=ImageFont.truetype(FONT, 30), fill=AMBER,
              anchor="mm", stroke_width=3, stroke_fill=NIGHT)
    banner.save(OUT_DIR / "page_banner_960x300.png")


def make_background(art: Image.Image) -> None:
    """The art, blurred and very dark, so the page's text stays the thing you read."""
    big = art.resize((1920, round(art.height * 1920 / art.width)), Image.LANCZOS)
    top = max(0, (big.height - 1080) // 2)
    background = big.crop((0, top, 1920, top + 1080)).filter(ImageFilter.GaussianBlur(6))
    ImageEnhance.Brightness(background).enhance(0.32).save(OUT_DIR / "page_background_1920x1080.jpg", quality=82)


# Draws one line of glowing text onto `image`. It is its own function because the
# thumbnail needs it three times (the name and two lines of words).
#   glow    how far the halo spreads, in pixels (the blur's radius)
#   stroke  how thick the dark outline round the letters is, in pixels
# Two Python idioms used inside:
#   fill + (255,)   joins two tuples: (r, g, b) + (255,) gives (r, g, b, 255),
#                   the colour with "fully solid" added as its fourth number.
#                   The comma in (255,) is what makes it a one-item tuple.
#   tuple[int, int, int]   a "type hint": it only documents that the value is
#                   three whole numbers; Python does not enforce it.
def glow_text(image: Image.Image, at: tuple[float, float], text: str, font: ImageFont.FreeTypeFont,
              fill: tuple[int, int, int], glow: int, stroke: int) -> None:
    """Draws `text` with a soft halo of its own colour behind it (the "neon"
    look), then a dark outline, then the letters. `at` is the text's left-middle."""
    # 1. The halo: the text alone on a see-through layer, blurred, laid on twice.
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(at, text, font=font, fill=fill + (255,), anchor="lm", stroke_width=stroke, stroke_fill=fill + (255,))
    halo = layer.filter(ImageFilter.GaussianBlur(glow))
    image.alpha_composite(halo)
    image.alpha_composite(halo)
    # 2. The letters, with a dark edge so they read on any background.
    ImageDraw.Draw(image).text(at, text, font=font, fill=fill + (255,), anchor="lm", stroke_width=stroke, stroke_fill=NIGHT + (255,))


def make_thumbnail(art: Image.Image) -> None:
    """The YouTube thumbnail. What a thumbnail needs, and how this one does it:
      - ONE focal point: the art is zoomed in so Seven is big, on the right;
      - HIGH CONTRAST: colours pushed up, and the left side darkened so the
        words sit on near-black;
      - FEW, BIG WORDS that still read at phone size: the name, and five words
        saying what you do;
      - a glow round the words in the game's own teal and amber."""
    width, height = 1280, 720
    # Zoom in 1.55 times and choose the window so Seven lands right of centre.
    zoom = 1.55
    big = art.resize((round(art.width * zoom), round(art.height * zoom)), Image.LANCZOS)
    # Seven stands in the middle of the art. Starting the window at the art's
    # left edge puts Seven about three quarters of the way across the
    # thumbnail, clear of the words on the left.
    left = 0
    top = big.height - height  # keep the bottom of the picture: that is where Seven stands
    frame = big.crop((left, top, left + width, top + height))
    frame = ImageEnhance.Color(frame).enhance(1.45)      # more colour
    frame = ImageEnhance.Contrast(frame).enhance(1.15)   # deeper darks, brighter lights
    frame = ImageEnhance.Brightness(frame).enhance(1.12)
    image = frame.convert("RGBA")

    # A dark veil that is solid at the left edge and gone by 62% of the width.
    veil = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    veil_draw = ImageDraw.Draw(veil)
    for x in range(width):
        share = max(0.0, 1.0 - x / (width * 0.62))
        veil_draw.line([(x, 0), (x, height)], fill=NIGHT + (round(235 * share ** 0.8),))
    image.alpha_composite(veil)

    glow_text(image, (48, 150), "SEEDSHOT", ImageFont.truetype(FONT, 190), TEAL, glow=18, stroke=8)
    words = ImageFont.truetype(FONT, 92)
    glow_text(image, (56, 345), "SHOOT ROBOTS.", words, AMBER, glow=10, stroke=6)
    glow_text(image, (56, 455), "GROW A FOREST.", words, (179, 242, 115), glow=10, stroke=6)

    # The badge: a teal pill with dark words, bottom left.
    badge_font = ImageFont.truetype(FONT, 50)
    badge_text = "FREE BROWSER GAME"
    draw = ImageDraw.Draw(image)
    text_width = draw.textlength(badge_text, font=badge_font)
    box = (48, 580, 48 + text_width + 56, 668)
    draw.rounded_rectangle(box, radius=44, fill=TEAL + (255,), outline=NIGHT + (255,), width=5)
    draw.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2 - 2), badge_text, font=badge_font, fill=NIGHT + (255,), anchor="mm")

    final = image.convert("RGB")
    final.save(OUT_DIR / "youtube_thumbnail_1280x720.jpg", quality=92)
    # The size it is shown at in a phone's list: if the words read here, they read anywhere.
    final.resize((320, 180), Image.LANCZOS).save(OUT_DIR / "youtube_thumbnail_preview_320.jpg", quality=90)


if __name__ == "__main__":
    key_art = Image.open(KEY_ART).convert("RGB")
    make_banner(key_art)
    make_background(key_art)
    make_thumbnail(key_art)
    for name in ("page_banner_960x300.png", "page_background_1920x1080.jpg",
                 "youtube_thumbnail_1280x720.jpg", "youtube_thumbnail_preview_320.jpg"):
        print(f"{name}: {(OUT_DIR / name).stat().st_size // 1024} KB")
