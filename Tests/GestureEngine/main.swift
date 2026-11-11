import CoreGraphics
import Foundation

// Gesture-engine regression tests. Run with scripts/test-gestures.sh.
//
// The grid mirrors the default letter layer: 3x3 keys of 78x72pt. Swipe
// labels and hidden symbol targets come from the real layout tables, wired up
// the same way KeyboardView does while the symbol labels are hidden.

let keyWidth: CGFloat = 78
let keyHeight: CGFloat = 72
let halfSide = min(keyWidth, keyHeight) / 2
let hiddenSymbolGate: CGFloat = 0.80 // KeyboardView.symbolSwipeMinimumReach, overlay hidden

func makeEngine() -> GestureEngine {
    let engine = GestureEngine()
    var regions: [GridPosition: CGRect] = [:]
    for row in 0..<3 {
        for col in 0..<3 {
            regions[GridPosition(row: row, col: col)] = CGRect(
                x: CGFloat(col) * keyWidth, y: CGFloat(row) * keyHeight,
                width: keyWidth, height: keyHeight
            )
        }
    }
    engine.updateKeyRegions(regions)
    let letters = KeyboardLayoutData.letterGrid
    let overlay = KeyboardLayoutData.symbolOverlayGrid
    engine.labeledDirections = { pos in
        var directions = Set(letters[pos.row][pos.col].swipes.keys)
        if pos == GridPosition(row: 2, col: 0) { directions.insert(.bottomRight) } // tab
        return directions
    }
    engine.hiddenTargetDirections = { pos in
        Set(overlay[pos.row][pos.col].swipes.keys).subtracting(engine.labeledDirections(pos))
    }
    engine.hiddenTargetMinimumReach = { hiddenSymbolGate }
    return engine
}

/// What the keyboard types for a gesture result on the letter layer with the
/// symbol labels hidden (mirrors KeyboardView.handleSwipe).
func typed(_ result: GestureResult) -> String {
    let letters = KeyboardLayoutData.letterGrid
    let overlay = KeyboardLayoutData.symbolOverlayGrid
    switch result {
    case .tap(let pos):
        return letters[pos.row][pos.col].tap
    case .swipe(let pos, let direction, let reach):
        let key = letters[pos.row][pos.col]
        if let char = key.swipes[direction] { return char }
        if reach >= hiddenSymbolGate, let char = overlay[pos.row][pos.col].swipes[direction] { return char }
        return key.tap
    case .swipeBack(let pos, _, _), .circle(let pos):
        return letters[pos.row][pos.col].tap.uppercased()
    default:
        return "<none>"
    }
}

/// A straight stroke on `key`, touching down at `offset` from the key centre
/// and travelling `length` points at `degrees` (0 = right, counter-clockwise,
/// screen y down), sampled every 4pt like a fast flick.
func stroke(
    on key: GridPosition, degrees: Double, length: CGFloat,
    offset: CGPoint = .zero, engine: GestureEngine = makeEngine()
) -> GestureResult {
    let centre = CGPoint(
        x: CGFloat(key.col) * keyWidth + keyWidth / 2 + offset.x,
        y: CGFloat(key.row) * keyHeight + keyHeight / 2 + offset.y
    )
    let radians = degrees * .pi / 180
    let ux = CGFloat(cos(radians)), uy = CGFloat(-sin(radians))
    engine.touchBegan(at: centre)
    var travelled: CGFloat = 4
    while travelled < length {
        engine.touchMoved(to: CGPoint(x: centre.x + ux * travelled, y: centre.y + uy * travelled))
        travelled += 4
    }
    return engine.touchEnded(at: CGPoint(x: centre.x + ux * length, y: centre.y + uy * length))
}

var failures = 0
var passes = 0

func expect(_ name: String, _ actual: String, _ expected: String) {
    if actual == expected {
        passes += 1
        print("  ok   \(name)")
    } else {
        failures += 1
        print("  FAIL \(name): typed \"\(actual)\", expected \"\(expected)\"")
    }
}

let iKey = GridPosition(row: 0, col: 2)
let tKey = GridPosition(row: 2, col: 0)
let eKey = GridPosition(row: 2, col: 1)
let committed = halfSide * 1.0 // a flick to the key edge

print("\"?\" vs \"x\" on the i key")
// Leftward flicks that dip below horizontal, the way a right thumb arcs.
for dip in [0.0, 5, 10, 15, 20] {
    expect("left flick dipping \(Int(dip))° types ?", typed(stroke(on: iKey, degrees: 180 + dip, length: committed)), "?")
}
expect("left flick touching down low on the key types ?",
       typed(stroke(on: iKey, degrees: 188, length: committed, offset: CGPoint(x: 8, y: 14))), "?")
expect("short left flick (under the symbol gate) still types x, not ?",
       typed(stroke(on: iKey, degrees: 195, length: halfSide * 0.65)), "x")
// "x" itself must stay easy to hit.
for angle in [205.0, 225, 245] {
    expect("down-left flick at \(Int(angle))° types x", typed(stroke(on: iKey, degrees: angle, length: committed)), "x")
}
expect("plain tap types i", typed(stroke(on: iKey, degrees: 180, length: 4)), "i")

print("labeled letters keep their wider sector next to empty directions")
// "e": left is empty, bottom-left is "," — a crooked "," still lands.
expect("e flick at 200° types ,", typed(stroke(on: eKey, degrees: 200, length: committed)), ",")
// "t": short crooked "y" stroke near the hidden top symbol still types y.
expect("short t flick at 72° types y", typed(stroke(on: tKey, degrees: 72, length: halfSide * 0.65)), "y")
expect("t flick at 45° types y", typed(stroke(on: tKey, degrees: 45, length: committed)), "y")

print("taps that drift stay taps")
let oKey = GridPosition(row: 1, col: 1)
// A thumb rolling off a fast tap moves the contact point 15-20pt. On the key
// that types the centre letter, wherever the drift heads.
for angle in [0.0, 45, 90, 135, 180, 225, 270, 315] {
    expect("o tap drifting 20pt at \(Int(angle))° types o", typed(stroke(on: oKey, degrees: angle, length: 20)), "o")
}
// The same drift from near the key edge crosses into the neighbour. That is
// still a tap, not a swipe toward the neighbour ("b" for "o").
expect("o tap near right edge drifting 17pt into r types o",
       typed(stroke(on: oKey, degrees: 0, length: 17, offset: CGPoint(x: keyWidth / 2 - 5, y: 0))), "o")
expect("o tap near top edge drifting 17pt into n types o",
       typed(stroke(on: oKey, degrees: 90, length: 17, offset: CGPoint(x: 0, y: -(keyHeight / 2 - 5)))), "o")
expect("e tap near left edge drifting 17pt into t types e",
       typed(stroke(on: eKey, degrees: 180, length: 17, offset: CGPoint(x: -(keyWidth / 2 - 5), y: 0))), "e")
// Deliberate swipes still land, including short ones and ones that cross.
expect("short o flick right (0.65 half-sides) types b", typed(stroke(on: oKey, degrees: 0, length: halfSide * 0.65)), "b")
expect("o swipe right into r types b", typed(stroke(on: oKey, degrees: 0, length: keyWidth * 0.8)), "b")
expect("o swipe up-left types q", typed(stroke(on: oKey, degrees: 135, length: committed)), "q")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
