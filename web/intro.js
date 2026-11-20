// intro.js - plays the intro clip over Godot's loading screen in the web build.
//
// Loaded by the web page through the export preset's "head include" (see
// export_presets.cfg) and copied next to index.html by tools\godot.ps1.
//
// THE ONE RULE: the clip must never be able to block the game. This file only
// ADDS a <video> on top of the page and later removes it. It never touches the
// engine. Every way the clip can go wrong (blocked autoplay, an old browser, a
// failed download, a stall) ends in the same place: leave(), which removes the
// clip and shows whatever is underneath, exactly as the page worked before.
//
// HOW IT KNOWS THE GAME IS READY: Godot's own page script (in index.html) calls
// statusOverlay.remove() when the engine has started, which takes the element
// with id "status" out of the page. So "the #status element is gone" means
// "the game is running". That is watched with a MutationObserver (a browser
// tool that calls a function whenever the page's elements change).
//
// THE TIMELINE
//   page opens     the clip starts, muted, over the loading screen
//   game ready     if the clip is still playing, let it finish; a click, tap
//                  or key press now skips it
//   clip ends      if the game is not ready, the last frame stays on screen
//   both done      the clip fades out and is removed

// Everything is wrapped in one function that runs straight away, so none of
// these names leak out and clash with Godot's own script.
(function () {
	'use strict';

	// --- Numbers to tune ---------------------------------------------------
	const CLIP_URL = 'intro.mp4';
	// If the clip has not started playing this long after the page opened,
	// give up on it (a blocked autoplay or a dead download).
	const START_TIMEOUT_MS = 4000;
	// Once the game is ready, the clip may stay at most this much longer. It is
	// longer than the clip itself (7.8 s), so it only matters if the clip stalls.
	const AFTER_READY_LIMIT_MS = 10000;
	// How long the fade-out takes. Keep it the same as the "transition" in intro.css.
	const FADE_MS = 400;

	// --- State -------------------------------------------------------------
	let video = null;        // the <video> element, or null once it is gone
	let skipHint = null;     // the "press any key" line, or null
	let gameReady = false;   // true once Godot has started the game
	let clipEnded = false;   // true once the clip has played to its end
	let hasLeft = false;     // true once leave() has run (it must run only once)

	// Removes the clip for good and hands the page back to the game. Safe to
	// call from anywhere, any number of times.
	// `why` is a short note for the browser's console (F12), so it is easy to
	// see afterwards what ended the clip.
	function leave(why) {
		if (hasLeft) {
			return;
		}
		hasLeft = true;
		console.info('Intro clip ended: ' + (typeof why === 'string' ? why : 'no reason given'));
		document.body.classList.remove('intro-on');
		// Stop listening for the skip press ("true" matches how it was added).
		window.removeEventListener('pointerdown', onSkipPress, true);
		window.removeEventListener('keydown', onSkipPress, true);
		if (skipHint) {
			skipHint.remove();
			skipHint = null;
		}
		if (video) {
			const leaving = video;
			video = null;
			leaving.classList.add('intro-leaving');  // intro.css fades it out
			// After the fade, take it out of the page and free the download.
			setTimeout(function () {
				leaving.pause();
				leaving.remove();
			}, FADE_MS);
		}
		// Give the keyboard back to the game.
		const canvas = document.getElementById('canvas');
		if (canvas) {
			canvas.focus();
		}
	}

	// Leaves only when BOTH things are true: the game is ready and the clip is over.
	function leaveIfBothDone() {
		if (gameReady && clipEnded) {
			leave('the clip finished and the game is ready');
		}
	}

	// A click, tap or key press while the clip is up. Before the game is ready
	// it does nothing (there is nothing to skip to). After that it skips.
	function onSkipPress(event) {
		if (hasLeft || !gameReady) {
			return;
		}
		// Use this press up, so the same click does not also press a button on
		// the title screen underneath.
		event.preventDefault();
		event.stopPropagation();
		leave('skipped by a click, tap or key');
	}

	// Called once, when Godot has started the game.
	function onGameReady() {
		if (gameReady) {
			return;
		}
		gameReady = true;
		if (hasLeft) {
			return;
		}
		// Show the hint, and stop waiting if the clip stalls from here on.
		skipHint = document.createElement('div');
		skipHint.id = 'intro-skip';
		// A phone has no keys to press: 'ontouchstart' exists only on touch screens.
		skipHint.textContent = ('ontouchstart' in window) ? 'Tap to skip' : 'Click or press any key to skip';
		document.body.appendChild(skipHint);
		setTimeout(function () { leave('the clip stalled after the game was ready'); }, AFTER_READY_LIMIT_MS);
		leaveIfBothDone();
	}

	// Builds the <video> and starts it. Runs once the page's elements exist.
	function start() {
		const status = document.getElementById('status');
		if (!status) {
			return;  // not Godot's usual page, or the game is already running: do nothing
		}

		video = document.createElement('video');
		video.id = 'intro-clip';
		video.src = CLIP_URL;
		// muted + playsInline + autoplay is the combination every browser,
		// phones included, allows to start without a click. The clip has no
		// sound track anyway.
		video.muted = true;
		video.defaultMuted = true;
		video.playsInline = true;
		video.setAttribute('playsinline', '');
		video.setAttribute('muted', '');
		video.autoplay = true;
		video.preload = 'auto';
		video.disablePictureInPicture = true;
		// No "loop": when it ends, the browser holds the last frame by itself.

		video.addEventListener('ended', function () {
			clipEnded = true;
			leaveIfBothDone();
		});
		// The file is missing, broken, or a kind this browser cannot play.
		video.addEventListener('error', function () { leave('the video file could not be loaded or played'); });

		document.body.appendChild(video);
		document.body.classList.add('intro-on');

		// play() returns a "promise": .catch runs if the browser refuses to play.
		try {
			const playing = video.play();
			if (playing && typeof playing.catch === 'function') {
				playing.catch(function (err) { leave('the browser refused to play it: ' + err); });
			}
		} catch (err) {
			leave('play() failed: ' + err);
		}

		// Still not moving after START_TIMEOUT_MS? Give up on the clip.
		setTimeout(function () {
			if (video && video.currentTime === 0) {
				leave('the clip never started');
			}
		}, START_TIMEOUT_MS);

		// Listen for the skip press. The last argument, true, means "tell me
		// first, before the game's canvas hears about it".
		window.addEventListener('pointerdown', onSkipPress, true);
		window.addEventListener('keydown', onSkipPress, true);

		// WATCH FOR "GAME READY" (the #status element leaving the page), and
		// for Godot showing an error notice, in which case the clip must get
		// out of the way so the message can be read.
		const notice = document.getElementById('status-notice');
		const observer = new MutationObserver(function () {
			if (!document.getElementById('status')) {
				observer.disconnect();  // stop watching: the job is done
				onGameReady();
			} else if (notice && notice.style.display === 'block') {
				observer.disconnect();
				leave('Godot showed an error notice');
			}
		});
		// Watch <body>'s list of children (for the removal) and style changes
		// anywhere inside it (for the error notice appearing).
		observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style'] });
	}

	// The script tag has "defer", so the page's elements exist by now. If
	// anything at all goes wrong while setting up, drop the clip and carry on.
	try {
		start();
	} catch (err) {
		console.warn('Intro clip skipped:', err);
		leave('setting it up failed');
	}
}());
