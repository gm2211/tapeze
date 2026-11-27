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

print("split keyboard on wide screens")
// Default 294pt keyboard: 78pt keys with 2pt gaps (a 238pt grid), a 2pt gap,
// and a one-key 78pt rail, so one half is 318pt wide.
func sizing(_ mode: SplitKeyboardMode, width: CGFloat) -> SplitSizing {
    SplitSizing.resolve(mode: mode, totalWidth: width, fullKeyWidth: keyWidth, fullRailWidth: 78, spacing: 2)
}
func split(width: CGFloat, railOnRight: Bool = true, mode splitMode: SplitKeyboardMode = .wideScreens) -> SplitMirrorLayout? {
    let size = sizing(splitMode, width: width)
    let gridWidth = size.keyWidth * 3 + 4
    let rail = size.railWidth
    let gridX = railOnRight ? width - gridWidth - 2 - rail : rail + 2
    return SplitMirrorLayout.make(
        enabled: size.isSplit, totalWidth: width, keyWidth: size.keyWidth, spacing: 2,
        primaryGridX: gridX, mainGridWidth: gridWidth, railWidth: rail,
        primaryRailOnRight: railOnRight
    )
}
func mode(_ layout: SplitMirrorLayout?) -> String { layout == nil ? "single" : "split" }
expect("iPhone portrait (393pt) stays single", mode(split(width: 393)), "single")
expect("narrow landscape (700pt) stays single", mode(split(width: 700)), "single")
expect("iPad / unfolded (1000pt) splits", mode(split(width: 1000)), "split")
expect("setting off keeps one keyboard", mode(split(width: 1000, mode: .off)), "single")
expect("Always splits iPhone portrait (393pt)", mode(split(width: 393, mode: .always)), "split")
expect("Always splits unfolded portrait (700pt)", mode(split(width: 700, mode: .always)), "split")
let squeezed = sizing(.always, width: 393)
// (393 - 12 - 12) / 8 = 46.125pt keys, rail one key wide.
expect("Always narrows keys to fit two halves", "\(squeezed.keyWidth),\(squeezed.railWidth)", "46.125,46.125")
expect("Always keeps full keys where they fit", "\(sizing(.always, width: 1000).keyWidth)", "78.0")
if let mirror = split(width: 393, mode: .always) {
    // Halves are 4 x 46.125 + 6 = 190.5pt; the primary grid starts at 393 - 190.5.
    expect("squeezed halves leave a 12pt middle gap", "\(393 - 2 * (mirror.maxX - mirror.minX))", "12.0")
    expect("squeezed mirror grid touch maps onto the primary grid", "\(60 + mirror.offset(forX: 60))", "\(60 + 393 - 190.5 - 48.125)")
}
if let mirror = split(width: 1000) {
    // Primary: grid 682...920, rail 922...1000. Mirror: rail 0...78, grid 80...318.
    expect("mirror rail sits on the outer left edge", "\(mirror.railX),\(mirror.gridX)", "0.0,80.0")
    expect("mirror grid touch maps onto the primary grid", "\(120 + mirror.offset(forX: 120))", "722.0")
    expect("mirror rail touch maps onto the primary rail", "\(10 + mirror.offset(forX: 10))", "932.0")
    expect("primary touches are not shifted", "\(mirror.offset(forX: 700))", "0.0")
    expect("the gap between halves is not shifted", "\(mirror.offset(forX: 450))", "0.0")
}
if let mirror = split(width: 1000, railOnRight: false) {
    // Primary: rail 0...78, grid 80...318. Mirror: grid 682...920, rail 922...1000.
    expect("rail-left primary puts the mirror rail on the right edge", "\(mirror.railX),\(mirror.railOnRight)", "922.0,true")
    expect("its grid touch maps onto the primary grid", "\(700 + mirror.offset(forX: 700))", "98.0")
    expect("its rail touch maps onto the primary rail", "\(990 + mirror.offset(forX: 990))", "68.0")
}

print("globe out-and-back toggles the split")
func globeStroke(_ path: [CGPoint]) -> String {
    let engine = makeEngine()
    let globe = CGRect(x: keyWidth - 20, y: keyHeight - 20, width: 40, height: 40)
    engine.updateGlobeRegion(globe)
    let origin = CGPoint(x: globe.midX, y: globe.midY)
    engine.touchBegan(at: origin)
    for p in path.dropLast() { engine.touchMoved(to: CGPoint(x: origin.x + p.x, y: origin.y + p.y)) }
    let last = path.last ?? .zero
    if case .specialSwipe(let special) = engine.touchEnded(at: CGPoint(x: origin.x + last.x, y: origin.y + last.y)) {
        return "\(special)"
    }
    return "<none>"
}
let outAndBackLeft = (1...12).map { CGPoint(x: -CGFloat($0) * 4, y: 0) } + (0...11).reversed().map { CGPoint(x: -CGFloat($0) * 4, y: 0) }
expect("globe swipe left and back right toggles split", globeStroke(outAndBackLeft), "globeBackAndForth")
let outAndBackRight = (1...12).map { CGPoint(x: CGFloat($0) * 4, y: 0) } + (0...11).reversed().map { CGPoint(x: CGFloat($0) * 4, y: 0) }
expect("globe swipe right and back left toggles split", globeStroke(outAndBackRight), "globeBackAndForth")
expect("straight globe swipe left is not the split toggle", globeStroke((1...12).map { CGPoint(x: -CGFloat($0) * 4, y: 0) }), "globeSwipeLeft")

print("holding a letter offers its accents")
expect("e hold: number first, then accents", HoldPicker.choicesForHeldKey(letter: "e", number: "8").joined(), "8éèêëēėę")
expect("h has no accents, so only its number", HoldPicker.choicesForHeldKey(letter: "h", number: "4").joined(), "4")
expect("capital A gets capital accents", Diacritics.variants(of: "A").joined(), "ÀÁÂÄÆÃÅĀ")
expect("capital S drops ß, which has no one-letter capital", Diacritics.variants(of: "S").joined(), "ŚŠŞ")
expect("every swiped letter with accents is on the default layout",
       Diacritics.variants.keys.filter { letter in
           !KeyboardLayoutData.letterGrid.flatMap { $0 }.contains { $0.tap == letter || $0.swipes.values.contains(letter) }
       }.sorted().joined(), "")
var picker = HoldPicker(choices: ["8", "é", "è", "ê"], anchor: CGPoint(x: 100, y: 50), cellWidth: 38)
expect("strip opens on the number", picker.selected ?? "", "8")
picker.track(CGPoint(x: 112, y: 50))
expect("a small wobble keeps the number", picker.selected ?? "", "8")
picker.track(CGPoint(x: 138, y: 30))
expect("one cell right picks é", picker.selected ?? "", "é")
picker.track(CGPoint(x: 400, y: 50))
expect("sliding past the end stops on the last choice", picker.selected ?? "", "ê")
picker.track(CGPoint(x: -200, y: 50))
expect("sliding past the start stops on the first choice", picker.selected ?? "", "8")

print("a held swipe knows its letter before lifting")
func held(on key: GridPosition, degrees: Double, length: CGFloat) -> String {
    let engine = makeEngine()
    let centre = CGPoint(x: CGFloat(key.col) * keyWidth + keyWidth / 2, y: CGFloat(key.row) * keyHeight + keyHeight / 2)
    let radians = degrees * .pi / 180
    let end = CGPoint(x: centre.x + CGFloat(cos(radians)) * length, y: centre.y - CGFloat(sin(radians)) * length)
    engine.touchBegan(at: centre)
    var travelled: CGFloat = 4
    while travelled < length {
        engine.touchMoved(to: CGPoint(x: centre.x + CGFloat(cos(radians)) * travelled, y: centre.y - CGFloat(sin(radians)) * travelled))
        travelled += 4
    }
    let peek = typed(engine.provisionalResult(at: end))
    let still = engine.hasActiveGesture ? "" : " (gesture was ended)"
    return peek + still
}
expect("o held after swiping left is c", held(on: oKey, degrees: 180, length: committed), "c")
expect("o held after swiping up is u", held(on: oKey, degrees: 90, length: committed), "u")
expect("e held without moving is e", held(on: eKey, degrees: 0, length: 0), "e")

print("touches are read in the layout the keys are drawn in")
do {
    let layout = CGSize(width: 393, height: 300)
    // In step: the touch view's own coordinates are used as they are.
    let inStep = TouchPointResolver.point(
        local: CGPoint(x: 40, y: 50),
        inWindow: CGPoint(x: 40, y: 600),
        surfaceSize: layout,
        layoutSize: layout,
        layoutOriginInWindow: CGPoint(x: 0, y: 550)
    )
    expect("an up-to-date touch view keeps its own point", "\(inStep.x),\(inStep.y)", "40.0,50.0")
    // iOS grew the keyboard from 250 to 300pt after it appeared. The keys
    // were redrawn 50pt higher but the touch view kept its old 250pt frame,
    // so its local point is 50pt off. The window point is not.
    let stale = TouchPointResolver.point(
        local: CGPoint(x: 40, y: 0),
        inWindow: CGPoint(x: 40, y: 600),
        surfaceSize: CGSize(width: 393, height: 250),
        layoutSize: layout,
        layoutOriginInWindow: CGPoint(x: 0, y: 550)
    )
    expect("a stale touch view is measured from the window", "\(stale.x),\(stale.y)", "40.0,50.0")
}

print("split choice remembered per screen")
do {
    func kind(_ w: CGFloat, _ h: CGFloat, regular: Bool = false) -> String {
        ScreenConfiguration.classify(screenSize: CGSize(width: w, height: h), bothSizeClassesRegular: regular).rawValue
    }
    expect("closed foldable / iPhone upright is small portrait", kind(393, 852), "smallPortrait")
    expect("iPhone sideways is small landscape", kind(852, 393), "smallLandscape")
    expect("unfolded inner screen upright is large portrait", kind(669, 900), "largePortrait")
    expect("unfolded inner screen sideways is large landscape", kind(900, 669), "largeLandscape")
    expect("regular size classes count as large", kind(500, 800, regular: true), "largePortrait")

    func eff(_ base: SplitKeyboardMode, _ c: ScreenConfiguration?, _ saved: [String: Bool] = [:]) -> String {
        SplitPreference.effectiveMode(base: base, configuration: c, savedChoices: saved).rawValue
    }
    expect("large screens split by default, upright too", eff(.wideScreens, .largePortrait), "always")
    expect("large landscape splits by default", eff(.wideScreens, .largeLandscape), "always")
    expect("small portrait keeps the wide-screen rule", eff(.wideScreens, .smallPortrait), "wideScreens")
    expect("unknown screen keeps the app setting", eff(.wideScreens, nil), "wideScreens")
    expect("app setting Off stays off on large screens", eff(.off, .largeLandscape), "off")
    let saved = ["largePortrait": false, "smallPortrait": true]
    expect("a saved single wins on its screen", eff(.wideScreens, .largePortrait, saved), "off")
    expect("a saved split wins on its screen", eff(.off, .smallPortrait, saved), "always")
    expect("other screens ignore that choice", eff(.wideScreens, .largeLandscape, saved), "always")
}

print("tool column wheel")
do {
    let count = ToolColumnItem.items(emoji: EmojiUsage.defaults).count
    expect("4 tools + 12 emoji", "\(count)", "16")
    let h: CGFloat = 294
    let maxOffset = ToolColumnMetrics.maxOffset(itemCount: count, height: h)
    expect("content runs past one screen", "\(maxOffset)", "672.0") // 16*60+6-294
    expect("top row at rest is undo", "\(ToolColumnMetrics.index(atY: 20, offset: 0, itemCount: count) ?? -1)", "0")
    expect("fourth row at rest is copy", "\(ToolColumnMetrics.index(atY: 200, offset: 0, itemCount: count) ?? -1)", "3")
    expect("scrolled one row, the top is redo", "\(ToolColumnMetrics.index(atY: 20, offset: 60, itemCount: count) ?? -1)", "1")
    expect("slow release snaps to the nearest row", "\(ToolColumnMetrics.resting(offset: 95, velocity: 0, itemCount: count, height: h))", "120.0")
    expect("a flick carries on", "\(ToolColumnMetrics.resting(offset: 60, velocity: 1000, itemCount: count, height: h))", "300.0")
    expect("a flick never passes the end", "\(ToolColumnMetrics.resting(offset: 600, velocity: 5000, itemCount: count, height: h))", "672.0")
    expect("pulling above the top gives way slowly", "\(ToolColumnMetrics.dragged(-30, itemCount: count, height: h))", "-10.0")
}

print("emoji ranking")
expect("unused: the default order", EmojiUsage.ranked(counts: [:]).joined(), EmojiUsage.defaults.joined())
expect("most-picked first, ties keep the default order",
       EmojiUsage.ranked(counts: ["🔥": 3, "🙏": 3, "😂": 1]).prefix(4).joined(), "🙏🔥😂❤️")

print("undo history")
func steps(_ h: EditHistory) -> String {
    h.undoStack.map { edit -> String in
        switch edit { case .inserted(let t): return "+" + t; case .deleted(let t): return "-" + t }
    }.joined(separator: "|")
}
do {
    var h = EditHistory()
    for c in "hello " { h.recordInsert(String(c)) }
    for c in "wor" { h.recordInsert(String(c)) }
    expect("a word and its space are one step", steps(h), "+hello |+wor")
    h.recordInsert("PASTED TEXT")
    h.recordInsert("x")
    expect("a paste is its own step", steps(h), "+hello |+wor|+PASTED TEXT|+x")
    var d = EditHistory()
    for c in "dlrow olleh" { d.recordDelete(String(c)) } // backspacing "hello world" from the end
    expect("backspace runs group by word", steps(d), "-world|-hello ")
    let undone = d.takeUndo()
    expect("undo takes the last step", "\(undone.map { "\($0)" } ?? "nil")", "deleted(\"hello \")")
    expect("and offers it to redo", "\(d.canRedo)", "true")
    d.recordInsert("a")
    expect("new typing clears redo", "\(d.canRedo)", "false")
}

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
