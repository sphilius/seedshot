"""make_cover.py - builds the itch.io cover image from the key art.

WHY: itch needs one cover picture (630 x 500) and shows it small in lists, such
as the jam's grid of entries. This script crops the key art around Seven and
the HELIOS tower, then paints the SEEDSHOT logo on it in the game's own marker
font, so the cover can be remade any time the art changes.

USE (from the project folder):   python tools/make_cover.py
OUT:   itch/cover_630x500.png        the cover to upload
       itch/cover_preview_315.png    the same at list size, to check it reads

Needs the Pillow library (pip install pillow).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent  # the project folder (one above tools/)
# The same picture the title screen uses, so the cover matches what players see.
KEY_ART = ROOT / "art" / "sprites" / "title_art.jpg"
FONT = ROOT / "art" / "fonts" / "PermanentMarker-Regular.ttf"
OUT_DIR = ROOT / "itch"

COVER_SIZE = (630, 500)       # what itch recommends
LOGO_TEXT = "SEEDSHOT"
LOGO_COLOR = (89, 230, 217)   # the title screen's teal
OUTLINE_COLOR = (13, 13, 18)  # near-black, so the logo reads on any background
# Where the logo's centre sits, as shares of the cover's width and height:
# across the dark tower, between the HELIOS sign and Seven.
LOGO_CENTRE = (0.5, 0.36)
# The logo is made as wide as this share of the cover.
LOGO_WIDTH_SHARE = 0.90


def crop_box(art_width: int, art_height: int) -> tuple[int, int, int, int]:
    """The part of the key art to keep: (left, top, right, bottom) in pixels.

    The cover is 630:500 (1.26 wide for every 1 tall). The full height is kept,
    from the HELIOS sign down to Seven's feet, centred left-to-right on Seven,
    who stands in the middle of the picture.
    """
    top = 0
    bottom = art_height
    width = round((bottom - top) * COVER_SIZE[0] / COVER_SIZE[1])
    left = (art_width - width) // 2  # // divides and rounds down to a whole number
    return left, top, left + width, bottom


def fit_font(draw: ImageDraw.ImageDraw, wanted_width: float) -> ImageFont.FreeTypeFont:
    """The biggest font size at which the logo is no wider than `wanted_width`."""
    size = 20
    font = ImageFont.truetype(str(FONT), size)
    # Grow the size one step at a time until the next step would be too wide.
    while True:
        bigger = ImageFont.truetype(str(FONT), size + 2)
        # textbbox returns (left, top, right, bottom) of the text's painted area.
        left, _top, right, _bottom = draw.textbbox((0, 0), LOGO_TEXT, font=bigger)
        if right - left > wanted_width:
            return font
        size += 2
        font = bigger


def main() -> None:
    """Crops the key art, paints the logo on it, and saves the two pictures."""
    art = Image.open(KEY_ART).convert("RGB")
    # art.size is (width, height); the * "unpacks" that pair into two arguments.
    cover = art.crop(crop_box(*art.size))
    # LANCZOS is a high-quality way to shrink a picture.
    cover = cover.resize(COVER_SIZE, Image.Resampling.LANCZOS)

    draw = ImageDraw.Draw(cover)
    font = fit_font(draw, COVER_SIZE[0] * LOGO_WIDTH_SHARE)
    centre = (COVER_SIZE[0] * LOGO_CENTRE[0], COVER_SIZE[1] * LOGO_CENTRE[1])
    # anchor="mm" means the position given is the MIDDLE of the text.
    # stroke_width paints an outline of that many pixels round every letter.
    draw.text(centre, LOGO_TEXT, font=font, fill=LOGO_COLOR, anchor="mm",
              stroke_width=7, stroke_fill=OUTLINE_COLOR)

    OUT_DIR.mkdir(exist_ok=True)
    cover.save(OUT_DIR / "cover_630x500.png")
    # The size it is really seen at in a list, to check the logo still reads.
    small = cover.resize((315, 250), Image.Resampling.LANCZOS)
    small.save(OUT_DIR / "cover_preview_315.png")
    print("wrote", OUT_DIR / "cover_630x500.png")


# This runs main() only when the file is run directly, not when it is imported.
if __name__ == "__main__":
    main()
