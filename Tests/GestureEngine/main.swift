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
    expect("4 tools + 12 emoji + all emoji", "\(count)", "17")
    // Default keyboard: 294pt tall, 72pt key rows, 2pt gaps, so a row is 74pt.
    let h: CGFloat = 294, row: CGFloat = 74, gap: CGFloat = 2
    expect("at rest four cells fill the column exactly", "\(4 * row - gap)", "294.0")
    let maxOffset = ToolColumnMetrics.maxOffset(itemCount: count, rowHeight: row, gap: gap, height: h)
    expect("the end rests on a whole row", "\(maxOffset)", "962.0") // 13 rows down
    expect("top row at rest is undo, beside the a row", "\(ToolColumnMetrics.index(atY: 20, offset: 0, rowHeight: row, itemCount: count) ?? -1)", "0")
    expect("fourth row at rest is copy, beside the space bar", "\(ToolColumnMetrics.index(atY: 250, offset: 0, rowHeight: row, itemCount: count) ?? -1)", "3")
    expect("scrolled one row, the top is redo", "\(ToolColumnMetrics.index(atY: 20, offset: row, rowHeight: row, itemCount: count) ?? -1)", "1")
    expect("slow release snaps to the nearest row", "\(ToolColumnMetrics.resting(offset: 120, velocity: 0, rowHeight: row, maxOffset: maxOffset))", "148.0")
    expect("a flick carries on", "\(ToolColumnMetrics.resting(offset: 74, velocity: 1000, rowHeight: row, maxOffset: maxOffset))", "296.0")
    expect("a flick never passes the end", "\(ToolColumnMetrics.resting(offset: 800, velocity: 5000, rowHeight: row, maxOffset: maxOffset))", "962.0")
    expect("pulling above the top gives way slowly", "\(ToolColumnMetrics.dragged(-30, maxOffset: maxOffset))", "-10.0")
}

print("tool column width")
do {
    func res(_ available: CGFloat, _ mode: ToolColumnConfig.SpareWidth = .twoColumns) -> String {
        let r = ToolColumnLayout.resolve(available: available, mode: mode, gap: 2)
        return "\(r.columns)x\(Int(r.width.rounded()))+\(Int(r.stripe.rounded()))"
    }
    expect("exactly one column: no stripe", res(92), "1x92+0")
    expect("narrower than one: the column shrinks", res(80), "1x80+0")
    expect("a little over: stripe on the outer edge", res(110), "1x92+18")
    expect("two 60pt cells fit: two columns", res(122), "2x122+0")
    expect("two columns grow to two full cells", res(175), "2x175+0")
    expect("past two full cells: stripe again", res(250), "2x186+64")
    expect("always one: the rest is stripe", res(175, .oneColumn), "1x92+83")
    expect("widen: no stripe", res(175, .widen), "1x175+0")
    expect("rows round up", "\(ToolColumnLayout.rowCount(itemCount: 17, columns: 2))", "9")
    func idx(_ x: CGFloat, _ y: CGFloat) -> String {
        "\(ToolColumnLayout.index(at: CGPoint(x: x, y: y), offset: 0, rowHeight: 74, width: 150, columns: 2, itemCount: 17) ?? -1)"
    }
    expect("two columns: left of the first row is undo", idx(20, 20), "0")
    expect("two columns: right of the first row is redo", idx(130, 20), "1")
    expect("two columns: second row right is copy", idx(130, 90), "3")
    expect("past the last item: nothing", idx(130, 8 * 74 + 10), "-1")
}

print("tool column settings")
do {
    func names(_ items: [ToolColumnItem]) -> String {
        items.map { item -> String in
            switch item {
            case .undo: return "U"
            case .redo: return "R"
            case .paste: return "P"
            case .copy: return "C"
            case .allEmoji: return "*"
            case .emoji(let e): return e
            }
        }.joined()
    }
    var config = ToolColumnConfig.default
    config.recentCount = 3
    expect("default order, all emoji last", names(config.items(recents: ["😂", "❤️", "👍", "🙏"])), "URPC😂❤️👍*")
    config.pinnedEmoji = ["👍", "🍕"]
    expect("pinned before recents, not repeated", names(config.items(recents: ["😂", "👍", "❤️", "🙏"])), "URPC👍🍕😂❤️🙏*")
    config.slots.insert(config.slots.remove(at: 5), at: 0) // most-used first
    config.slots[4].isOn = false // copy, fifth after the move
    expect("reordered, copy hidden", names(config.items(recents: ["😂"])), "😂URP👍🍕*")
    var broken = ToolColumnConfig.default
    broken.slots = [ToolColumnConfig.Slot(entry: .redo, isOn: false), ToolColumnConfig.Slot(entry: .redo, isOn: true)]
    broken.recentCount = 99
    let fixed = broken.normalized()
    expect("normalize drops duplicates and adds missing entries", fixed.slots.map(\.entry.rawValue).joined(separator: ","), "redo,undo,paste,copy,pinnedEmoji,recentEmoji")
    expect("normalize keeps the count in range", "\(fixed.recentCount)", "24")
}

print("emoji picker")
do {
    let layout = EmojiPickerLayout(size: CGSize(width: 300, height: 240), sections: [["a", "b"], Array(repeating: "x", count: 15)])
    expect("seven 42pt cells fit across 300pt", "\(layout.columns)", "7")
    expect("each section starts on its own row", layout.sectionStartRows.map(String.init).joined(separator: ","), "0,1")
    expect("rows in total", "\(layout.rowCount)", "4")
    expect("tap on the first cell", layout.emoji(at: CGPoint(x: 10, y: 10), offset: 0) ?? "-", "a")
    expect("tap past a short section's end", layout.emoji(at: CGPoint(x: 200, y: 10), offset: 0) ?? "-", "-")
    expect("second section, first row", layout.emoji(at: CGPoint(x: 10, y: 50), offset: 0) ?? "-", "x")
    expect("the bar: ABC on the left", "\(layout.barTarget(at: CGPoint(x: 10, y: 230)) == .abc)", "true")
    expect("the bar: backspace on the right", "\(layout.barTarget(at: CGPoint(x: 290, y: 230)) == .backspace)", "true")
    expect("the bar: second tab", "\(layout.barTarget(at: CGPoint(x: 250, y: 230)) == .category(1))", "true")
    expect("catalog has smileys", "\(EmojiCatalog.categories.first?.emoji.contains("😂") == true)", "true")
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

print("space bar cursor control")
do {
    /// Plays `points` at `dt` seconds apart and returns the moves it caused.
    func play(_ points: [CGPoint], dt: TimeInterval, holdFirst: TimeInterval = 0) -> (moves: [String], tracker: SpaceCursorTracker) {
        var tracker = SpaceCursorTracker()
        tracker.begin(at: points[0], time: 0)
        var moves: [String] = []
        for (i, p) in points.dropFirst().enumerated() {
            switch tracker.observe(p, time: holdFirst + dt * Double(i + 1)) {
            case .characters(let n): moves.append("c\(n)")
            case .words(let n): moves.append("w\(n)")
            case nil: break
            }
        }
        return (moves, tracker)
    }
    func line(_ from: CGPoint, _ to: CGPoint, steps: Int = 10) -> [CGPoint] {
        (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
    }
    let o = CGPoint(x: 200, y: 330)

    // Quick flick: nothing live, GestureEngine handles it on lift.
    let flick = play(line(o, CGPoint(x: 160, y: 332)), dt: 0.012)
    expect("a quick flick moves nothing while down", flick.moves.joined(separator: ","), "")
    expect("a quick flick leaves the lift to the engine", "\(flick.tracker.didMoveCursor)", "false")

    // Quick back-and-forth: one word in the first leg's direction.
    let leftBack = play(line(o, CGPoint(x: 165, y: 331), steps: 6) + line(CGPoint(x: 165, y: 331), CGPoint(x: 200, y: 330), steps: 6).dropFirst(), dt: 0.012)
    expect("quick left-and-back moves a word left", leftBack.moves.joined(separator: ","), "w-1")
    let rightBack = play(line(o, CGPoint(x: 235, y: 331), steps: 6) + line(CGPoint(x: 235, y: 331), o, steps: 6).dropFirst(), dt: 0.012)
    expect("quick right-and-back moves a word right", rightBack.moves.joined(separator: ","), "w1")
    var wiggle = [o]
    for _ in 0..<3 {
        wiggle += line(o, CGPoint(x: 235, y: 330), steps: 4).dropFirst()
        wiggle += line(CGPoint(x: 235, y: 330), o, steps: 4).dropFirst()
    }
    expect("three wiggles move three words", play(wiggle, dt: 0.01).moves.joined(separator: ","), "w1,w1,w1")

    // Circles: clockwise right, counter-clockwise left (screen y is down).
    func circle(clockwise: Bool, startAngle: Double, turns: Double = 1.1, r: CGFloat = 22) -> [CGPoint] {
        let center = CGPoint(x: o.x - r * CGFloat(cos(startAngle)), y: o.y - r * CGFloat(sin(startAngle)))
        let n = Int(36 * turns)
        return (0...n).map { i in
            let a = startAngle + (clockwise ? 1 : -1) * 2 * .pi * Double(i) / 36
            return CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
        }
    }
    expect("clockwise circle from the top moves right", play(circle(clockwise: true, startAngle: -.pi / 2), dt: 0.008).moves.first ?? "", "w1")
    expect("clockwise circle from the bottom moves right", play(circle(clockwise: true, startAngle: .pi / 2), dt: 0.008).moves.first ?? "", "w1")
    expect("counter-clockwise circle from the top moves left", play(circle(clockwise: false, startAngle: -.pi / 2), dt: 0.008).moves.first ?? "", "w-1")
    expect("counter-clockwise circle from the bottom moves left", play(circle(clockwise: false, startAngle: .pi / 2), dt: 0.008).moves.first ?? "", "w-1")

    expect("a small clockwise circle moves right", play(circle(clockwise: true, startAngle: -.pi / 2, r: 15), dt: 0.008).moves.first ?? "", "w1")
    expect("a small counter-clockwise circle moves left", play(circle(clockwise: false, startAngle: 0, r: 15), dt: 0.008).moves.first ?? "", "w-1")

    // Slow drag: trackpad, one character per 10pt once past the dead zone.
    let slow = play(line(o, CGPoint(x: 260, y: 333), steps: 30), dt: 0.03)
    let total = slow.moves.compactMap { Int($0.dropFirst()) }.reduce(0, +)
    expect("a slow 60pt drag moves the cursor live", "\(slow.tracker.mode)", "trackpad")
    expect("a slow 60pt drag moves about 5 characters", "\(total)", "5")
    let back = play(line(o, CGPoint(x: 260, y: 330), steps: 20) + line(CGPoint(x: 260, y: 330), CGPoint(x: 230, y: 330), steps: 10).dropFirst(), dt: 0.03)
    expect("trackpad follows the finger back", "\(back.moves.compactMap { Int($0.dropFirst()) }.reduce(0, +))", "1")
    expect("trackpad does not turn reversals into words", "\(back.moves.contains { $0.hasPrefix("w") })", "false")

    // Hold, then drag.
    let held = play(line(o, CGPoint(x: 170, y: 330), steps: 10), dt: 0.02, holdFirst: 0.4)
    expect("hold then drag left moves characters left", "\(held.moves.compactMap { Int($0.dropFirst()) }.reduce(0, +))", "-2")

    // A held press whose thumb rolls a little still types a space.
    let roll = play(line(o, CGPoint(x: 211, y: 334), steps: 10), dt: 0.05)
    expect("a slow roll inside the dead zone moves nothing", "\(roll.tracker.didMoveCursor)", "false")

    // Swipe up and swipe up-and-back stay the engine's.
    let up = play(line(o, CGPoint(x: 206, y: 270), steps: 10), dt: 0.04)
    expect("a slow swipe up is vetoed", "\(up.tracker.mode)", "vetoed")
    let upBack = play(line(o, CGPoint(x: 204, y: 270), steps: 6) + line(CGPoint(x: 204, y: 270), o, steps: 6).dropFirst(), dt: 0.015)
    expect("swipe up and back is vetoed", "\(upBack.tracker.mode)", "vetoed")
    expect("swipe up and back moves nothing", upBack.moves.joined(separator: ","), "")
}

print("\nClipboard paste")
do {
    func r(_ access: Bool = true, s: String? = nil, u: URL? = nil, img: Bool = false, n: Int = 0) -> String {
        "\(ClipboardPaste.resolve(hasFullAccess: access, string: s, url: u, hasImages: img, itemCount: n))"
    }
    expect("text is typed", r(s: "hi", n: 1), "\(ClipboardPaste.text("hi"))")
    expect("a copied link is typed as its address", r(u: URL(string: "https://a.b/c"), n: 1), "\(ClipboardPaste.text("https://a.b/c"))")
    expect("an image explains the system Paste", r(img: true, n: 1), "\(ClipboardPaste.notice(ClipboardPaste.imageNotice))")
    expect("an image with a caption types the caption", r(s: "cap", img: true, n: 1), "\(ClipboardPaste.text("cap"))")
    expect("an empty clipboard says so", r(), "\(ClipboardPaste.notice(ClipboardPaste.emptyNotice))")
    expect("other content explains the system Paste", r(n: 1), "\(ClipboardPaste.notice(ClipboardPaste.otherNotice))")
    expect("no Full Access asks for it", r(false), "\(ClipboardPaste.notice(ClipboardPaste.noAccessNotice))")
}

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
