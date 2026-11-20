"""seven_facings.py - turn Seven (the locked cream-dome design) to face 8 directions.

WHY
    tools/seven_sprite.py draws Seven facing the viewer. The game used to mirror that one
    picture left or right. This script draws Seven again turned round a vertical axis,
    like a figure on a turntable, so the sprite can face all eight ways.

HOW (the idea, in plain words)
    Every body part of Seven is given a position in 3D: x (left/right), z (towards/away from
    the viewer). To turn Seven by an angle (called "yaw") we rotate those positions, then
    draw each part where it lands on the 64 x 64 picture, farthest part first so near parts
    cover far ones. At yaw 0 (facing the viewer) every shape here is the same as in
    seven_sprite.py, and the script CHECKS that: the front frame must equal the locked sprite.

    Rotation:  new_x = x*cos(yaw) + z*sin(yaw)      new_depth = -x*sin(yaw) + z*cos(yaw)
    A bigger depth means nearer to the viewer.

FRAME ORDER (matches Godot's angles, so the game can pick a frame with one rounding):
    0 East, 1 South-East, 2 South, 3 South-West, 4 West, 5 North-West, 6 North, 7 North-East
    "South" is down the screen, towards the viewer: the original front view.
    Frame i has yaw = 90 - 45*i degrees.

USAGE (from the project root)
    python tools/seven_facings.py

OUT
    art/sprites/gardener_bot_facings.png   512 x 64: eight 64 x 64 frames side by side
    art/source/klad/seven_facings@4x.png   the same at 4x on the floor colour, for looking

Needs: Pillow, numpy, scipy  (pip install pillow numpy scipy)
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import seven_sprite as locked  # the front view and its palette; same folder as this file

ROOT = Path(__file__).resolve().parent.parent
SIZE = locked.SIZE
X, Y = locked.X, locked.Y
OUTLINE, TEAL, TEAL_DARK = locked.OUTLINE, locked.TEAL, locked.TEAL_DARK
CREAM, CREAM_DARK = locked.CREAM, locked.CREAM_DARK
LEAF_LIGHT, LEAF_DARK = locked.LEAF_LIGHT, locked.LEAF_DARK
RUST_DARK, STEEL_DARK = locked.RUST_DARK, locked.STEEL_DARK
STEEL_LIGHT = (0x9A, 0xA5, 0xA8)  # from the game palette; only the back hatch uses it
CENTRE = 32.0  # Seven's vertical axis, in pixel columns
FRAMES = 8


def ellipse(cx, cy, rx, ry):
    """Mask of an ellipse (an oval)."""
    return ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1.0


def rect(x, y, w, h):
    """Mask of a w x h rectangle with its top-left pixel at (x, y)."""
    return (X >= x) & (X < x + w) & (Y >= y) & (Y < y + h)


def column_band(cx, half_width, y0, y1):
    """Mask of whole pixel columns within half_width of cx, between rows y0 and y1."""
    return (np.abs(X - cx) <= max(half_width, 0.5)) & (Y >= y0) & (Y <= y1)


def draw_frame(yaw_degrees: float) -> np.ndarray:
    """Paint Seven turned by `yaw_degrees` (0 = facing the viewer, 90 = facing right)."""
    yaw = math.radians(yaw_degrees)
    sin_y, cos_y = math.sin(yaw), math.cos(yaw)
    image = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)

    def project(x: float, z: float = 0.0):
        """Where a point at 3D (x, z) lands: (screen column, depth). Bigger depth = nearer."""
        return CENTRE + x * cos_y + z * sin_y, -x * sin_y + z * cos_y

    def paint(mask, colour) -> None:
        """Colour every pixel the mask covers, fully solid.
        `(*colour, 255)` is "unpacking": it spreads the three colour numbers out and adds
        the 4th (alpha 255 = not see-through). `image[mask] = ...` is "boolean indexing":
        numpy writes the value into exactly the pixels where the mask is True."""
        image[mask] = (*colour, 255)

    body = ellipse(32, 41, 12, 10)
    head = ellipse(32, 20, 15, 12)

    # ---- every part is (depth, draw order, function that paints it) -----------------------
    parts = []

    def add(depth: float, painter) -> None:
        """Queue one body part: how near it is, and a function that paints it later.
        Functions are ordinary values in Python, so a list can hold them and call each
        one when its turn comes (see the sorted(...) loop below). len(parts) is the order
        added, used to break ties between parts at the same depth."""
        parts.append((depth, len(parts), painter))

    # The seed tank on Seven's back: hidden behind the body from the front, it peeks out
    # at the sides and shows in full from behind.
    tank_x, tank_depth = project(0.0, -13.0)

    def paint_tank():
        """Paint the back tank. It is a "closure": an inner function that can read the
        variables around it (tank_x, paint) even though it runs later, from the queue."""
        tank = ellipse(tank_x, 41, 5, 7)
        paint(tank, CREAM)
        paint(tank & (X > tank_x + 1), CREAM_DARK)
        paint(tank & (Y <= 35), TEAL)  # the tank's cap

    add(tank_depth - 1.0, paint_tank)  # -1: behind the body even when sideways

    # Legs and feet: short and stumpy. Seen from the side the feet point forward.
    for leg_offset in (-5.5, 5.5):
        leg_x, leg_depth = project(leg_offset)

        def paint_leg(leg_x=leg_x):
            """Paint one leg and its foot. `leg_x=leg_x` copies this loop turn's value in
            now: without it every queued leg would read the loop's LAST leg_x, because a
            closure sees the variable, not the value it had at the time."""
            foot_width = 7.0 * abs(cos_y) + 9.0 * abs(sin_y)
            foot_x = leg_x + 2.0 * sin_y  # feet stick out the way Seven faces
            paint(rect(round(leg_x - 2.5), 49, 5, 6), RUST_DARK)
            paint(rect(round(foot_x - foot_width / 2.0), 54, round(foot_width), 3), TEAL)

        add(leg_depth - 2.0, paint_leg)

    # The body barrel: a cylinder looks the same from every side. Light comes from the
    # top left of the SCREEN, so the shading stays on the right whatever the yaw.
    def paint_body():
        paint(body, TEAL)
        paint(body & (X > 37), TEAL_DARK)
        band = body & rect(20, 47, 24, 3)
        paint(band, CREAM)
        paint(band & (X > 37), CREAM_DARK)

    add(0.0, paint_body)

    # The chest patch on the front, and a plain steel hatch on the back.
    for azimuth, is_front in ((0.0, True), (math.pi, False)):
        patch_x = CENTRE + 11.0 * math.sin(azimuth + yaw)
        patch_cos = math.cos(azimuth + yaw)  # 1 = facing us, 0 = edge on, negative = hidden

        def paint_patch(patch_x=patch_x, patch_cos=patch_cos, is_front=is_front):
            if patch_cos < 0.15:
                return
            half = 4.0 * patch_cos
            if is_front:
                paint(body & column_band(patch_x - 0.5, half - 0.5, 37, 41), CREAM)
                if patch_cos > 0.4:  # the two small marks only show when mostly face-on
                    paint(body & column_band(patch_x - 2.5 * patch_cos, 0.6, 38, 38), STEEL_DARK)
                    paint(body & column_band(patch_x + 1.0 * patch_cos, 1.1, 38, 38), STEEL_DARK)
            else:
                paint(body & column_band(patch_x - 0.5, half - 0.5, 37, 41), STEEL_DARK)
                if patch_cos > 0.4:
                    paint(body & column_band(patch_x - 0.5, 0.5, 39, 39), STEEL_LIGHT)

        add(0.5, paint_patch)

    # Shoulders (round joints) and arms. The left (cream) arm hangs; the right one is
    # raised, holding the seedling forward of the body.
    left_x, left_depth = project(-13.0)
    right_x, right_depth = project(13.0)
    add(left_depth, lambda: paint(ellipse(left_x, 37, 4, 4), TEAL))
    add(right_depth, lambda: paint(ellipse(right_x, 37, 4, 4), TEAL_DARK))
    add(left_depth + 0.1, lambda: paint(rect(round(left_x - 2.5 + 0.5), 40, 4, 6), CREAM))
    arm_x, arm_depth = project(13.5, 4.0)
    add(arm_depth, lambda: paint(rect(round(arm_x - 1.5), 40, 4, 4), CREAM_DARK))

    # The seedling, held out to the front-right. Hand, stem and two leaves share one depth.
    hand_x, hand_depth = project(16.0, 9.0)

    def paint_seedling():
        """Paint the hand and the seedling it holds (the game's little green signature)."""
        paint(rect(round(hand_x - 1), 38, 3, 3), CREAM_DARK)  # the hand
        paint(rect(round(hand_x), 33, 1, 5), LEAF_DARK)  # the stem
        paint(ellipse(hand_x - 1.5, 32, 2, 1.4), LEAF_LIGHT)  # left leaf
        paint(ellipse(hand_x + 2.5, 31, 2, 1.4), LEAF_LIGHT)  # right leaf

    # Turned away to the right the true depth would hide the sprout behind the body, and
    # the sprout is Seven's signature. So unless Seven faces away from us, it is kept just
    # in front of the body (but still behind the head, which is painted after the parts).
    seedling_depth = hand_depth if cos_y < -0.1 else max(hand_depth, 0.2)
    add(seedling_depth, paint_seedling)

    # Paint far to near. Python sorts the (depth, order) pairs, so equal depths keep the
    # order they were added in.
    for _depth, _order, painter in sorted(parts, key=lambda p: (p[0], p[1])):
        painter()

    # Neck ring and head are always on top of the body.
    paint(rect(25, 31, 14, 2), STEEL_DARK)
    paint(head, CREAM)
    paint(head & ~ellipse(29, 17, 15, 12), CREAM_DARK)  # shadow crescent, lower right

    # Stripe on the dome (front, and again at the back so the head reads from behind).
    for azimuth in (math.asin(-0.5), math.pi - math.asin(-0.5)):
        stripe_cos = math.cos(azimuth + yaw)
        if stripe_cos < 0.2:
            continue
        stripe_x = CENTRE + 13.0 * math.sin(azimuth + yaw)
        half = 2.5 * stripe_cos / math.cos(math.asin(0.5))
        stripe = head & column_band(stripe_x, half, 0, 21)
        paint(stripe, TEAL)
        paint(stripe & (Y >= 18), TEAL_DARK)

    # Eyes: two dark rectangles low on the face, only on the side facing us. The face is
    # treated as a plate of radius 11 (smaller than the head), so that in profile the one
    # visible eye sits well inside the dome and is at least 2 pixels wide.
    for eye_sin in (-4.0 / 11.0, 4.0 / 11.0):
        azimuth = math.asin(eye_sin)
        eye_cos = math.cos(azimuth + yaw)
        if eye_cos < 0.15:
            continue
        eye_x = CENTRE + 11.0 * math.sin(azimuth + yaw)
        half = max(1.0, 1.5 * eye_cos / math.cos(azimuth))
        paint(head & column_band(eye_x, half, 22, 26), OUTLINE)
        if half >= 1.5:  # a glint, only when the eye is wide enough to hold one
            paint(head & column_band(math.ceil(eye_x - half), 0.4, 22, 22), CREAM)
    paint(rect(33, 11, 3, 2), (0xFF, 0xFA, 0xEA))  # shine on the dome (fixed: the light is)

    # The dark outline, exactly as in the locked sprite.
    solid = image[..., 3] > 0
    image[ndimage.binary_dilation(solid) & ~solid] = (*OUTLINE, 255)
    return image


def main() -> None:
    """Draw the eight frames, check the front one against the locked sprite, save."""
    frames = [draw_frame(90.0 - 45.0 * i) for i in range(FRAMES)]

    front = np.array(Image.open(ROOT / "art/sprites/gardener_bot.png").convert("RGBA"))
    differing = int(np.any(frames[2] != front, axis=-1).sum())
    print(f"front frame differs from the locked sprite in {differing} pixels")
    if differing > 0:
        print("(it should be 0: the front frame is the locked design)")

    strip = Image.new("RGBA", (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.alpha_composite(Image.fromarray(frame, "RGBA"), (i * SIZE, 0))
    strip.save(ROOT / "art/sprites/gardener_bot_facings.png")

    big = strip.resize((SIZE * FRAMES * 3, SIZE * 3), Image.NEAREST)
    preview = Image.new("RGBA", big.size, (58, 66, 72, 255))  # the dark floor colour
    preview.alpha_composite(big)
    preview.save(ROOT / "art/source/klad/seven_facings@3x.png")
    print("built: gardener_bot_facings.png")


if __name__ == "__main__":
    main()
