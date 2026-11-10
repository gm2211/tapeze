#!/usr/bin/env bash
# Compiles the gesture engine and layout tables with a small test driver and
# runs it. Needs a Mac with Xcode command line tools (CoreGraphics).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build/gesture-tests"
mkdir -p "$OUT_DIR"

xcrun swiftc -O \
	-o "$OUT_DIR/gesture-tests" \
	"$ROOT_DIR/tapezeKeyboard/GestureEngine.swift" \
	"$ROOT_DIR/tapezeKeyboard/KeyboardLayout.swift" \
	"$ROOT_DIR/Tests/GestureEngine/Stubs.swift" \
	"$ROOT_DIR/Tests/GestureEngine/main.swift"

"$OUT_DIR/gesture-tests"
