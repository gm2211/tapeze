# Gesture demo

The MP4 records Tapeze's real SwiftUI keyboard and gesture recognizer in an isolated iPhone 17 Pro simulator. A temporary capture harness replays touch paths and shows captions, a touch marker, and the text returned by the existing keyboard callbacks. It does not inject the displayed characters or change the production app.

The sequence demonstrates loop capitalization, taps, secondary-letter swipes, horizontal space, and vertical delete. The verified callback sequence is `T`, `a`, `p`, `e`, `z`, `e`, space, `h`, `i`, `s`, delete, ending with `Tapeze hi`.

`gesture-demo.webp` is an animated WebP preview with rounded corners and a soft transparent edge. `gesture-demo.mp4` is the full-resolution H.264 recording. Playback has no audio and runs at the recorded speed.

## Reproduce

Requires Xcode, FFmpeg, WebP tools (`img2webp`), and an iPhone 17 Pro simulator (1206×2622 pixels). Apply the [capture patch](../../scripts/demo/readme-harness.patch) only to a disposable checkout, then build its `tapeze` scheme in Debug for the simulator. The patch adds a `--readme-demo` launch mode; production source stays untouched.

1. Install that Debug build in the disposable simulator.
2. Start recording with `xcrun simctl io <device-id> recordVideo --codec=h264 capture.mov`.
3. Launch with `xcrun simctl launch --console-pty <device-id> com.gm2211.tapeze --readme-demo`.
4. Wait for `README_DEMO_FINAL output="Tapeze hi" expected="Tapeze hi" pass=true`, then allow a short final hold and stop recording with Ctrl-C.
5. Find the first complete demo frame in the recording, then run `scripts/export-readme-demo.sh capture.mov <start-seconds> <duration-seconds>` from the repository root.

The 700×390-point demo canvas is rotated inside the portrait simulator to preserve legibility. The export script crops and rotates it back, then creates both deliverables. The checked-in recording used a 4-second start offset and an 18-second duration.
