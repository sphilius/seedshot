"""web_dpr_check.py - s26 HD display test for the WEB build, at chosen device pixel ratios.

WHY
    The browser pane in the Claude app can only emulate a ratio-1 desktop or its own phone, and
    cannot save pictures into the repo. This drives a headless Chrome directly through its
    "DevTools protocol" (the same remote-control channel Chrome's developer tools use), so it
    can pretend to be any screen: a desktop at ratio 1, 2 or 3, or a phone with touch.

WHAT IT CHECKS, per screen
    1. The canvas's BACKING size (canvas.width/height, real pixels) is its CSS size times
       window.devicePixelRatio: proof the game draws at the device's real resolution.
    2. It presses Play and saves a screenshot of the arena (docs/s26/web_<name>.png).
    3. On touch screens: puts a finger down, drags it, and saves a close-up around the finger
       (docs/s26/web_<name>_touch.png) so you can see the stick's knob sits under the finger.

USAGE (serve build\\web first, e.g. the seedshot-web preview, then):
    python tools/web_dpr_check.py --url http://localhost:8063/
"""
import argparse
import asyncio
import base64
import json
import os
import shutil
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path

import websockets  # a small library for websocket connections (the DevTools channel is one)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/s26"
CHROME = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")
PORT = 9333  # the DevTools port for this run (any free port)

# The screens to test: name, CSS width, CSS height, device pixel ratio, is it a touch phone?
SCREENS = [
    ("desktop_r1", 1280, 720, 1, False),
    ("desktop_r2", 1280, 720, 2, False),
    ("desktop_r3", 1280, 720, 3, False),
    ("phone_r3_landscape", 812, 375, 3, True),
]
LOAD_SECONDS = 14   # time for the engine and game to load in a software-rendered headless Chrome
PLAY_SECONDS = 5    # time after pressing Play before the arena screenshot


class DevTools:
    """One connection to one Chrome tab. `send` sends a command and waits for ITS answer
    (answers carry the id of the command they answer; other messages are events, skipped)."""

    def __init__(self, socket):
        self.socket = socket
        self.next_id = 0

    async def send(self, method: str, **params) -> dict:
        """Send one DevTools command (e.g. "Page.navigate") and return Chrome's answer.
        IDIOMS: `async def` makes a coroutine, a function that can pause while waiting for the
        network; `await` is where it pauses. `**params` collects keyword arguments into a dict."""
        self.next_id += 1
        my_id = self.next_id
        await self.socket.send(json.dumps({"id": my_id, "method": method, "params": params}))
        while True:
            message = json.loads(await self.socket.recv())
            if message.get("id") == my_id:
                if "error" in message:
                    raise RuntimeError(f"{method}: {message['error']}")
                return message.get("result", {})

    async def js(self, expression: str):
        """Run JavaScript in the page and return its value."""
        result = await self.send("Runtime.evaluate", expression=expression, returnByValue=True)
        return result.get("result", {}).get("value")

    async def screenshot(self, path: Path, clip: dict = None) -> None:
        """Save a PNG of the page (or of `clip` = {x, y, width, height, scale} in CSS pixels)."""
        params = {"format": "png"}
        if clip:
            params["clip"] = clip
        data = (await self.send("Page.captureScreenshot", **params))["data"]
        path.write_bytes(base64.b64decode(data))

    async def tap_or_click(self, x: float, y: float, touch: bool) -> None:
        """Press at CSS point (x, y): a finger tap on a touch screen, a mouse click otherwise."""
        if touch:
            point = [{"x": x, "y": y, "id": 1}]
            await self.send("Input.dispatchTouchEvent", type="touchStart", touchPoints=point)
            await self.send("Input.dispatchTouchEvent", type="touchEnd", touchPoints=[])
        else:
            for kind in ("mousePressed", "mouseReleased"):
                await self.send("Input.dispatchMouseEvent", type=kind, x=x, y=y, button="left", clickCount=1)


async def check_screen(url: str, name: str, width: int, height: int, ratio: int, touch: bool) -> dict:
    """Open the game on one emulated screen, measure the canvas, play, screenshot."""
    # A new tab for each screen (DevTools' HTTP endpoint /json/new makes one).
    request = urllib.request.Request(f"http://127.0.0.1:{PORT}/json/new?about:blank", method="PUT")
    tab = json.loads(urllib.request.urlopen(request).read())
    async with websockets.connect(tab["webSocketDebuggerUrl"], max_size=None) as socket:
        tools = DevTools(socket)
        await tools.send("Emulation.setDeviceMetricsOverride", width=width, height=height,
                         deviceScaleFactor=ratio, mobile=touch)
        await tools.send("Emulation.setTouchEmulationEnabled", enabled=touch, maxTouchPoints=5 if touch else 1)
        await tools.send("Page.enable")
        await tools.send("Page.navigate", url=url)
        await asyncio.sleep(LOAD_SECONDS)
        size = await tools.js("""(() => { const c = document.querySelector('canvas');
            return {dpr: devicePixelRatio, css: [c.clientWidth, c.clientHeight], backing: [c.width, c.height]}; })()""")
        # The title screen's Play button sits at the middle of the 1280 x 720 layout, at y = 413.
        # Stretch aspect "keep" letterboxes the layout into the page, so convert layout -> CSS.
        scale = min(width / 1280, height / 720)
        left, top = (width - 1280 * scale) / 2, (height - 720 * scale) / 2
        await tools.tap_or_click(left + 640 * scale, top + 413 * scale, touch)
        await asyncio.sleep(PLAY_SECONDS)
        await tools.screenshot(OUT / f"web_{name}.png")
        if touch:
            # Finger down on the left half, then drag 50 CSS px right: the move stick shows a ring
            # where the finger landed and its knob under the finger.
            start, end = (left + 200 * scale, top + 500 * scale), (left + 200 * scale + 50, top + 500 * scale)
            await tools.send("Input.dispatchTouchEvent", type="touchStart", touchPoints=[{"x": start[0], "y": start[1], "id": 1}])
            for step in range(1, 6):
                x = start[0] + (end[0] - start[0]) * step / 5
                await tools.send("Input.dispatchTouchEvent", type="touchMove", touchPoints=[{"x": x, "y": end[1], "id": 1}])
                await asyncio.sleep(0.05)
            await asyncio.sleep(0.4)
            box = 80  # CSS pixels each side of the finger
            await tools.screenshot(OUT / f"web_{name}_touch.png",
                                   clip={"x": end[0] - box, "y": end[1] - box, "width": box * 2, "height": box * 2, "scale": 1})
            await tools.send("Input.dispatchTouchEvent", type="touchEnd", touchPoints=[])
            size["finger_css"] = [round(end[0], 1), round(end[1], 1)]
    return size


def main() -> None:
    """Start a headless Chrome, check every screen, print one line per screen, close Chrome."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", default="http://localhost:8063/")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    profile = tempfile.mkdtemp(prefix="seedshot_chrome_")  # a throwaway profile, so no real browser data is touched
    chrome = subprocess.Popen([str(CHROME), "--headless=new", f"--remote-debugging-port={PORT}",
                               f"--user-data-dir={profile}", "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required",
                               "--window-size=1400,900", "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(3)
        for name, width, height, ratio, touch in SCREENS:
            size = asyncio.run(check_screen(args.url, name, width, height, ratio, touch))
            follows = size["backing"] == [round(size["css"][0] * size["dpr"]), round(size["css"][1] * size["dpr"])]
            print(f"{name}: dpr {size['dpr']}, css {size['css']}, backing {size['backing']}, "
                  f"backing = css x dpr: {'YES' if follows else 'NO'}" + (f", finger at {size['finger_css']}" if "finger_css" in size else ""))
    finally:
        chrome.terminate()
        chrome.wait(10)
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    main()
