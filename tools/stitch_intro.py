"""stitch_intro.py - joins the two opening-sequence clips with a hidden cut.

WHY: the two clips ("Past due" and "First light") were generated separately, so
where they meet the picture jumps: the second clip is framed slightly
differently, lit differently in places (plants dimmer, Seven brighter) and has a
different texture. This script removes as much of that jump as it can:

  1. TRIM     drops the glitchy first frames of part 1 and its long frozen tail,
              so the cut lands just as the block's lights finish going out.
  2. ALIGN    measures how part 1 is shifted/stretched compared with part 2 and
              warps part 1 so buildings and plants sit on the same pixels.
  3. RELIGHT  builds a soft "lighting map" (how much brighter or darker each
              area of part 2 is) and eases part 1 into it over its last second,
              while the lights are dimming anyway.
  4. BLEND    a very short dissolve (2 in-between frames) across the cut.

USE (from the project folder):
    python tools/stitch_intro.py            build the clip
    python tools/stitch_intro.py --measure  only print the measurements

Needs: opencv-python, numpy, and ffmpeg on the PATH.
"""
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent  # the project folder
CLIPS = ROOT / "art" / "video" / "opening sequence"
PART_1_PLAIN = CLIPS / "pt1-past_due_v7_silent.mp4"                # as generated
PART_1_UPSCALED = CLIPS / "pt1-past_due_v7_silent_upscaled_2x.mp4"  # Video2X copy
PART_2 = CLIPS / "pt2-first_light_silent.mp4"
OUT = CLIPS / "intro_v6_smoothed.mp4"

SIZE = (1920, 1080)  # output width, height
FPS = 24

# --- the edit, in frame numbers (24 frames = 1 second) ---
PART_1_FIRST = 3    # frames 0-2 of part 1 jump about (a generation glitch)
PART_1_LAST = 71    # the lights finish dimming here; frames 72-95 are frozen
PART_2_FIRST = 0    # part 2 is used from its first frame
RELIGHT_FRAMES = 24  # ease into part 2's lighting over this many frames
BLEND_FRAMES = 2    # in-between frames of the dissolve across the cut
LIGHT_BLUR = 45.0   # softness of the lighting map, in pixels (bigger = softer)
SHARPEN_RADIUS = 1.5  # width of the edges that get sharpened, in pixels
SHARPEN_AMOUNT = 0.9  # strength of the sharpening on part 1 (0 = none)

# The whole-picture colour match measured for version 4: (mean 1, gain, mean 2)
# for blue, green, red. OpenCV keeps colours in B, G, R order.
COLOUR_MATCH = [(20.26, 1.0864, 18.86), (15.61, 1.0108, 13.71), (8.22, 1.0392, 7.25)]


def read_frames(path: Path) -> list[np.ndarray]:
    """Every frame of a video, scaled to cover SIZE and cropped to exactly SIZE."""
    video = cv2.VideoCapture(str(path))
    frames = []
    while True:
        ok, frame = video.read()  # ok is False when the video has run out
        if not ok:
            break
        height, width = frame.shape[:2]
        # Scale so the frame COVERS the output, then crop the overhang evenly.
        scale = max(SIZE[0] / width, SIZE[1] / height)
        new_w, new_h = round(width * scale), round(height * scale)
        if (new_w, new_h) != (width, height):
            frame = cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
        left, top = (new_w - SIZE[0]) // 2, (new_h - SIZE[1]) // 2
        frames.append(frame[top:top + SIZE[1], left:left + SIZE[0]])
    video.release()
    return frames


def colour_match(frame: np.ndarray) -> np.ndarray:
    """Applies the whole-picture colour match to one part 1 frame."""
    out = frame.astype(np.float32)
    for channel, (mean_1, gain, mean_2) in enumerate(COLOUR_MATCH):
        out[..., channel] = (out[..., channel] - mean_1) * gain + mean_2
    return np.clip(out, 0, 255)


def sharpen(frame: np.ndarray) -> np.ndarray:
    """An "unsharp mask": adds back the difference between a frame and a blurred
    copy of itself, which makes edges crisper. Part 2 measures far crisper than
    part 1, so part 1 is sharpened to meet it part-way."""
    soft = cv2.GaussianBlur(frame, (0, 0), SHARPEN_RADIUS)
    return frame + SHARPEN_AMOUNT * (frame - soft)


def crispness(frame: np.ndarray) -> float:
    """How much fine detail a frame has (bigger = crisper or grainier).

    The Laplacian picks out edges; its variance is a standard sharpness score.
    """
    grey = cv2.cvtColor(np.clip(frame, 0, 255).astype(np.uint8), cv2.COLOR_BGR2GRAY)
    return float(cv2.Laplacian(grey, cv2.CV_64F).var())


def measure_alignment(still_1: np.ndarray, still_2: np.ndarray) -> np.ndarray:
    """The 2x3 "affine" matrix that moves part 1's picture onto part 2's.

    An affine matrix can shift, stretch, rotate and skew a picture. OpenCV's ECC
    method nudges the matrix until the two pictures line up as well as possible.
    Measured at half size on edges-friendly greyscale to keep it quick.
    """
    def prepare(frame: np.ndarray) -> np.ndarray:
        grey = cv2.cvtColor(np.clip(frame, 0, 255).astype(np.uint8), cv2.COLOR_BGR2GRAY)
        small = cv2.resize(grey, (SIZE[0] // 2, SIZE[1] // 2), interpolation=cv2.INTER_AREA)
        # Even out the very dark picture so buildings count as much as the neon.
        return cv2.createCLAHE(clipLimit=3.0).apply(small).astype(np.float32)

    matrix = np.eye(2, 3, dtype=np.float32)  # start from "no change"
    stop_when = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 300, 1e-6)
    score, matrix = cv2.findTransformECC(prepare(still_2), prepare(still_1), matrix,
                                         cv2.MOTION_AFFINE, stop_when, None, 5)
    matrix[:, 2] *= 2.0  # the shift was measured at half size: double it
    print(f"alignment score {score:.3f} (1.0 = perfect)")
    return matrix


def warp(frame: np.ndarray, matrix: np.ndarray) -> np.ndarray:
    """Moves a part 1 frame onto part 2's framing using the measured matrix."""
    # WARP_INVERSE_MAP because ECC gives the matrix in the "look-up" direction.
    return cv2.warpAffine(frame, matrix, SIZE, flags=cv2.INTER_LANCZOS4 | cv2.WARP_INVERSE_MAP,
                          borderMode=cv2.BORDER_REPLICATE)


def lighting_map(still_1: np.ndarray, still_2: np.ndarray) -> np.ndarray:
    """For each area and colour: how many times brighter part 2 is than part 1.

    Both pictures are blurred heavily first, so the map only holds broad
    lighting (this corner is dimmer, Seven is brighter), never fine detail.
    """
    soft_1 = cv2.GaussianBlur(still_1.astype(np.float32), (0, 0), LIGHT_BLUR)
    soft_2 = cv2.GaussianBlur(still_2.astype(np.float32), (0, 0), LIGHT_BLUR)
    # The +4 stops near-black areas (tiny numbers) from giving wild ratios.
    return np.clip((soft_2 + 4.0) / (soft_1 + 4.0), 0.5, 2.0)


def ease(t: float) -> float:
    """Smoothstep: 0 to 1 with a gentle start and a gentle finish."""
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def main() -> None:
    """Measures the two clips, then (unless --measure) builds the joined clip."""
    part_2 = read_frames(PART_2)
    plain = read_frames(PART_1_PLAIN)
    upscaled = read_frames(PART_1_UPSCALED)
    print(f"frames: part 1 plain {len(plain)}, upscaled {len(upscaled)}, part 2 {len(part_2)}")

    # Which copy of part 1 has a texture closer to part 2's? Compare crispness.
    target = crispness(part_2[PART_2_FIRST])
    score_plain, score_up = crispness(plain[PART_1_LAST]), crispness(upscaled[PART_1_LAST])
    print(f"crispness: part 2 {target:.1f} | part 1 plain {score_plain:.1f} | upscaled {score_up:.1f}")
    use_plain = abs(score_plain - target) < abs(score_up - target)
    part_1 = plain if use_plain else upscaled
    print("using part 1:", "plain (as generated)" if use_plain else "upscaled")

    still_1 = colour_match(part_1[PART_1_LAST])
    still_2 = part_2[PART_2_FIRST].astype(np.float32)
    matrix = measure_alignment(still_1, still_2)
    print("alignment matrix (stretch/skew | shift in pixels):")
    print(np.round(matrix, 4))
    light = lighting_map(warp(still_1, matrix), still_2)
    print(f"lighting map: darkest area x{light.min():.2f}, brightest x{light.max():.2f}")
    print(f"crispness of part 1 after sharpening: {crispness(sharpen(warp(still_1, matrix)) * light):.1f}")
    if "--measure" in sys.argv:
        return

    # ffmpeg receives raw frames on its standard input and encodes them.
    encoder = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24",
         "-s", f"{SIZE[0]}x{SIZE[1]}", "-r", str(FPS), "-i", "-", "-an",
         "-c:v", "libx264", "-crf", "17", "-preset", "slow", "-pix_fmt", "yuv420p",
         "-movflags", "+faststart", str(OUT)],
        stdin=subprocess.PIPE)

    def send(frame: np.ndarray) -> None:
        """Hands one finished frame to ffmpeg."""
        encoder.stdin.write(np.clip(frame, 0, 255).astype(np.uint8).tobytes())

    def part_1_frame(index: int) -> np.ndarray:
        """Part 1 frame `index`: colour matched, aligned, eased into part 2's light."""
        frame = sharpen(warp(colour_match(part_1[index]), matrix))
        # 0 until RELIGHT_FRAMES before the cut, then easing up to 1 at the cut.
        amount = ease(1.0 - (PART_1_LAST - index) / RELIGHT_FRAMES)
        return frame * (1.0 + amount * (light - 1.0))

    count = 0
    for index in range(PART_1_FIRST, PART_1_LAST + 1):
        send(part_1_frame(index))
        count += 1
    # The dissolve: part 1's frozen frames mixed with part 2's first frames.
    for step in range(BLEND_FRAMES):
        share = (step + 1) / (BLEND_FRAMES + 1)  # how much of part 2 shows
        before = part_1_frame(min(PART_1_LAST + 1 + step, len(part_1) - 1))
        after = part_2[PART_2_FIRST + step].astype(np.float32)
        send(before * (1.0 - share) + after * share)
        count += 1
    print(f"cut: part 2 is fully on screen from frame {count} ({count / FPS:.2f} s)")
    for frame in part_2[PART_2_FIRST + BLEND_FRAMES:]:
        send(frame)
        count += 1

    encoder.stdin.close()
    encoder.wait()
    print(f"wrote {OUT} ({count} frames, {count / FPS:.2f} s)")


# This runs main() only when the file is run directly, not when it is imported.
if __name__ == "__main__":
    main()
