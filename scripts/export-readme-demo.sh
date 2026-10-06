#!/usr/bin/env bash
set -euo pipefail

# Export the centered, clockwise-rotated 700x390pt demo canvas recorded on an
# iPhone 17 Pro simulator (1206x2622 pixels). The source is a real app recording.
# Usage: scripts/export-readme-demo.sh recording.mov start_seconds duration_seconds
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${1:?Pass the simulator recording path}"
START="${2:?Pass the first demo frame time in seconds}"
DURATION="${3:?Pass the demo duration in seconds}"
OUTPUT_DIR="$ROOT_DIR/docs/demo"
mkdir -p "$OUTPUT_DIR"

ffmpeg -hide_banner -loglevel error -y -ss "$START" -i "$INPUT" -t "$DURATION" \
  -vf 'crop=1170:2100:18:261,transpose=cclock,scale=1400:780:flags=lanczos,setsar=1,fps=30' \
  -an -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p -movflags +faststart \
  "$OUTPUT_DIR/gesture-demo.mp4"

# Animated WebP preserves smooth alpha corners without a large APNG payload.
FRAMES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tapeze-demo-frames.XXXXXX")"
trap 'rm -rf "$FRAMES_DIR"' EXIT
ffmpeg -hide_banner -loglevel error -y -i "$OUTPUT_DIR/gesture-demo.mp4" \
  -vf "fps=15,scale=840:468:flags=lanczos,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='255*clip((24-hypot(max(abs(X-W/2)-(W/2-24),0),max(abs(Y-H/2)-(H/2-24),0)))/4,0,1)'" \
  "$FRAMES_DIR/frame-%04d.png"
img2webp -loop 0 -lossy -q 85 -m 4 -d 67 "$FRAMES_DIR"/frame-*.png \
  -o "$OUTPUT_DIR/gesture-demo.webp"
