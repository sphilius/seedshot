"""serve_web.py - serve the exported web build locally so it can be played in a browser.

A Godot web build cannot be opened by double-clicking index.html: browsers refuse to
load the .wasm and .pck files from a file:// address. It has to come from a web
server, and this is the smallest one that works.

USAGE (from the project root, after `.\\tools\\godot.ps1 export`)
    python tools/serve_web.py            # then open http://127.0.0.1:8079
    python tools/serve_web.py --probe    # same, plus the audio probe described below

THE AUDIO PROBE (--probe)
    Browsers keep audio switched off until the player clicks or presses a key. To
    CHECK that from a script, --probe slips a few lines of JavaScript into index.html
    as it is served. Those lines record every AudioContext the game creates in
    `window.__audioProbe`, and count how many sounds were started. The files on disk
    are never changed, so the probe can never end up in the build uploaded to itch.
"""

from __future__ import annotations

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WEB_DIR = Path(__file__).resolve().parent.parent / "build" / "web"

# JavaScript that wraps the browser's AudioContext so a test can inspect it later.
AUDIO_PROBE = b"""<script>
(function () {
  var Real = window.AudioContext || window.webkitAudioContext;
  var probe = { contexts: [], soundsStarted: 0 };
  window.__audioProbe = probe;
  function Wrapped() {
    var ctx = new (Function.prototype.bind.apply(Real, [null].concat([].slice.call(arguments))))();
    probe.contexts.push(ctx);
    return ctx;
  }
  Wrapped.prototype = Real.prototype;
  window.AudioContext = Wrapped;
  window.webkitAudioContext = Wrapped;
  var realStart = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function () {
    probe.soundsStarted += 1;
    return realStart.apply(this, arguments);
  };
})();
</script>"""


class Handler(SimpleHTTPRequestHandler):
    """Serves files from build/web. With the probe on, index.html gets the script added."""

    # Class attribute, switched on by main() when --probe is passed.
    inject_probe = False

    def end_headers(self) -> None:
        # Tell the browser never to cache, so a fresh export always shows up on reload.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:
        """Handle one page/file request. Only index.html gets special treatment."""
        is_index = self.path.split("?")[0] in ("/", "/index.html")
        if not (self.inject_probe and is_index):
            super().do_GET()  # normal file serving from the parent class
            return
        html = (WEB_DIR / "index.html").read_bytes()
        html = html.replace(b"<head>", b"<head>" + AUDIO_PROBE, 1)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.end_headers()
        self.wfile.write(html)


def main() -> None:
    """Read the options and run the server until Ctrl+C."""
    parser = argparse.ArgumentParser(description="Serve build/web for local play-testing.")
    parser.add_argument("--port", type=int, default=8079)
    parser.add_argument("--probe", action="store_true", help="inject the audio probe")
    args = parser.parse_args()

    if not (WEB_DIR / "index.html").exists():
        raise SystemExit(f"No web build at {WEB_DIR}. Run: .\\tools\\godot.ps1 export")

    Handler.inject_probe = args.probe
    # functools.partial pre-fills the `directory` argument, so every request handler
    # the server creates serves files from build/web instead of the current folder.
    handler = functools.partial(Handler, directory=str(WEB_DIR))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Seedshot web build: http://127.0.0.1:{args.port}  (Ctrl+C to stop)")
    server.serve_forever()


if __name__ == "__main__":
    main()
