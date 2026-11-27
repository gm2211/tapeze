import CoreGraphics
import Foundation

// MARK: - Direction

enum SwipeDirection: String, CaseIterable, Codable, Identifiable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight

    var id: String { rawValue }

    var rowOffset: Int {
        switch self {
        case .topLeft, .top, .topRight: return -1
        case .left, .right: return 0
        case .bottomLeft, .bottom, .bottomRight: return 1
        }
    }

    var colOffset: Int {
        switch self {
        case .topLeft, .left, .bottomLeft: return -1
        case .top, .bottom: return 0
        case .topRight, .right, .bottomRight: return 1
        }
    }

    /// Angle in radians (0 = right, counter-clockwise)
    var angle: Double {
        switch self {
        case .right:       return 0
        case .topRight:    return .pi / 4
        case .top:         return .pi / 2
        case .topLeft:     return 3 * .pi / 4
        case .left:        return .pi
        case .bottomLeft:  return 5 * .pi / 4
        case .bottom:      return 3 * .pi / 2
        case .bottomRight: return 7 * .pi / 4
        }
    }

    static func fromAngle(_ angle: Double) -> SwipeDirection {
        // Normalize to 0..<2π
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a < 0 { a += 2 * .pi }

        // Each direction covers 45° sector
        let sector = Int((a + .pi / 8) / (.pi / 4)) % 8
        switch sector {
        case 0: return .right
        case 1: return .topRight
        case 2: return .top
        case 3: return .topLeft
        case 4: return .left
        case 5: return .bottomLeft
        case 6: return .bottom
        case 7: return .bottomRight
        default: return .right
        }
    }
}

// MARK: - Special Actions

enum SpecialAction {
    case globe
    case toggleLayer
    case backspace
    case enter
    case space
    case shift
    case tab
    case clipboard
    case dictation
}

// MARK: - Key Configuration

struct KeyConfig {
    let tap: String
    let swipes: [SwipeDirection: String]
    let specialAction: SpecialAction?
    let displayLabel: String? // Override display (e.g., icons)

    init(
        tap: String,
        swipes: [SwipeDirection: String] = [:],
        specialAction: SpecialAction? = nil,
        displayLabel: String? = nil
    ) {
        self.tap = tap
        self.swipes = swipes
        self.specialAction = specialAction
        self.displayLabel = displayLabel
    }

    var isSpecial: Bool { specialAction != nil }
}

// MARK: - Grid Position

struct GridPosition: Hashable {
    let row: Int
    let col: Int
}

// MARK: - Keyboard Layer

enum KeyboardLayer: CaseIterable {
    case letters
    case numbers
    case symbolsOnly
}

// MARK: - Layout Data

struct KeyboardLayoutData {
    static let customLayoutDefaultsKey = "customKeyboardLayout"

    // MARK: Letter Layer - Main 3x3 Grid

    static let letterGrid: [[KeyConfig]] = [
        // Row 0: a, n, i
        [
            KeyConfig(tap: "a", swipes: [.bottomRight: "v"]),
            KeyConfig(tap: "n", swipes: [.bottom: "l"]),
            KeyConfig(tap: "i", swipes: [.bottomLeft: "x"]),
        ],
        // Row 1: h, o, r
        [
            KeyConfig(tap: "h", swipes: [.right: "k"]),
            KeyConfig(tap: "o", swipes: [
                .topLeft: "q", .top: "u", .topRight: "p",
                .left: "c", .right: "b",
                .bottomLeft: "g", .bottom: "d", .bottomRight: "j",
            ]),
            KeyConfig(tap: "r", swipes: [.left: "m"]),
        ],
        // Row 2: t, e, s
        [
            KeyConfig(tap: "t", swipes: [.topRight: "y"]),
            KeyConfig(tap: "e", swipes: [
                .top: "w", .topRight: "'", .right: "z",
                .bottomLeft: ",", .bottom: ".", .bottomRight: ":",
            ]),
            KeyConfig(tap: "s", swipes: [
                .topLeft: "f", .bottomLeft: ";",
            ]),
        ],
    ]

    // MARK: Number Layer - Main 3x3 Grid

    static let numberGrid: [[KeyConfig]] = [
        // Row 0: 1, 2, 3
        [
            KeyConfig(tap: "1", swipes: [
                .topRight: "£", .left: "<", .right: "-",
                .bottomLeft: "$",
            ]),
            KeyConfig(tap: "2", swipes: [
                .topLeft: "`", .top: "^", .topRight: "´",
                .left: "+", .right: "!",
                .bottomLeft: "/", .bottomRight: "\\",
            ]),
            KeyConfig(tap: "3", swipes: [
                .left: "?", .right: "≥",
                .bottom: "=", .bottomRight: "€",
            ]),
        ],
        // Row 1: 4, 5, 6
        [
            KeyConfig(tap: "4", swipes: [
                .topLeft: "{", .topRight: "%",
                .left: "(", .bottomLeft: "[", .bottomRight: "_",
            ]),
            KeyConfig(tap: "5", swipes: [:]),
            KeyConfig(tap: "6", swipes: [
                .topLeft: "|", .topRight: "}",
                .right: ")", .bottomLeft: "@", .bottomRight: "]",
            ]),
        ],
        // Row 2: 7, 8, 9
        [
            KeyConfig(tap: "7", swipes: [
                .topLeft: "~", .top: "¨",
                .left: "<", .right: "*",
            ]),
            KeyConfig(tap: "8", swipes: [
                .topLeft: "\"", .topRight: "'",
                .bottomLeft: ",", .bottom: ".", .bottomRight: ":",
            ]),
            KeyConfig(tap: "9", swipes: [
                .topLeft: "&", .topRight: "°",
                .left: "#", .right: ">", .bottomLeft: ";",
            ]),
        ],
    ]

    // MARK: Symbol Overlay - Letter taps with symbol swipes

    static let symbolOverlayGrid: [[KeyConfig]] = [
        [
            KeyConfig(tap: "a", swipes: [.right: "-", .bottomLeft: "$", .bottom: "."]),
            KeyConfig(tap: "n", swipes: [
                .topLeft: "`", .top: "^", .topRight: "´",
                .left: "+", .right: "!",
                .bottomLeft: "/", .bottomRight: "\\",
            ]),
            KeyConfig(tap: "i", swipes: [.left: "?", .bottom: "=", .bottomRight: "€"]),
        ],
        [
            KeyConfig(tap: "h", swipes: [
                .topLeft: "{", .topRight: "%",
                .left: "(", .bottomLeft: "[", .bottomRight: "_",
            ]),
            KeyConfig(tap: "o", swipes: [:]),
            KeyConfig(tap: "r", swipes: [
                .topLeft: "|", .topRight: "}",
                .right: ")", .bottomLeft: "@", .bottomRight: "]",
            ]),
        ],
        [
            KeyConfig(tap: "t", swipes: [.topLeft: "~", .top: "¨", .left: "<", .right: "*"]),
            KeyConfig(tap: "e", swipes: [
                .topLeft: "\"", .topRight: "'",
                .bottomLeft: ",", .bottom: ".", .bottomRight: ":",
            ]),
            KeyConfig(tap: "s", swipes: [
                .top: "&", .topRight: "°",
                .left: "#", .right: ">", .bottomLeft: ";",
            ]),
        ],
    ]

    // MARK: Command Bar (right column)

    static func commandBar(for layer: KeyboardLayer) -> [KeyConfig] {
        [
            KeyConfig(tap: "", specialAction: .globe, displayLabel: "globe"),
            KeyConfig(
                tap: layer == .letters ? "123" : "abc",
                specialAction: .toggleLayer,
                displayLabel: layer == .letters ? "123" : "abc"
            ),
            KeyConfig(tap: "", specialAction: .backspace, displayLabel: "delete.left"),
        ]
    }

    // MARK: Bottom Row

    static func bottomRow(for layer: KeyboardLayer) -> [KeyConfig] {
        if layer == .letters {
            return [
                KeyConfig(tap: " ", specialAction: .space, displayLabel: "space"),
            ]
        } else {
            return [
                KeyConfig(tap: "0", swipes: [:]),
            ]
        }
    }

    // MARK: Persistent Overlays

    /// Characters that appear on specific keys regardless of layer
    struct PersistentOverlay {
        let position: GridPosition
        let direction: SwipeDirection
        let action: SpecialAction
        let displayLabel: String
    }

    static let persistentOverlays: [PersistentOverlay] = [
        // Tab on key (2,0) bottomRight
        PersistentOverlay(position: GridPosition(row: 2, col: 0), direction: .bottomRight, action: .tab, displayLabel: "⇥"),
        // Clipboard on key (0,0) topLeft
        PersistentOverlay(position: GridPosition(row: 0, col: 0), direction: .topLeft, action: .clipboard, displayLabel: "C"),
    ]

    /// ".com" shortcut on h key
    static let dotComPosition = GridPosition(row: 1, col: 0)

    static func activeLetterGrid() -> [[KeyConfig]] {
        resolvedGrids().letters
    }

    static func activeNumberGrid() -> [[KeyConfig]] {
        resolvedGrids().numbers
    }

    static func activeSymbolOverlayGrid() -> [[KeyConfig]] {
        resolvedGrids().symbolOverlay
    }

    private struct ResolvedGrids {
        let letters: [[KeyConfig]]
        let numbers: [[KeyConfig]]
        let symbolOverlay: [[KeyConfig]]
    }

    /// The grids are read on every render and every keypress, and the keyboard
    /// re-renders on each touch sample. Decoding the saved layout from the app
    /// group each time put a JSON decode on the input path, so resolve once and
    /// drop the cache when the layout can have changed: on save/restore in this
    /// process, and when the keyboard reappears after the app edited it.
    private static var cachedGrids: ResolvedGrids?

    private static func resolvedGrids() -> ResolvedGrids {
        if let cachedGrids { return cachedGrids }
        let saved = savedEditableLayout()
        let grids = ResolvedGrids(
            letters: saved?.letterGrid.map { row in row.map(\.keyConfig) } ?? letterGrid,
            numbers: saved?.numberGrid.map { row in row.map(\.keyConfig) } ?? numberGrid,
            symbolOverlay: saved?.symbolOverlayGrid.map { row in row.map(\.keyConfig) } ?? symbolOverlayGrid
        )
        cachedGrids = grids
        return grids
    }

    static func invalidateLayoutCache() {
        cachedGrids = nil
    }

    static func savedEditableLayout() -> EditableKeyboardLayout? {
        guard let data = UserDefaults(suiteName: KeyboardState.appGroupSuiteName)?.data(forKey: customLayoutDefaultsKey) else {
            return nil
        }
        guard var layout = try? JSONDecoder().decode(EditableKeyboardLayout.self, from: data) else {
            return nil
        }

        let containsZ = layout.letterGrid
            .flatMap { $0 }
            .contains { $0.cells.values.contains("z") }
        if !containsZ,
           layout.letterGrid.indices.contains(2),
           layout.letterGrid[2].indices.contains(1) {
            layout.letterGrid[2][1].setValue("z", at: .right)
            saveEditableLayout(layout)
        }

        return layout
    }

    static func saveEditableLayout(_ layout: EditableKeyboardLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults(suiteName: KeyboardState.appGroupSuiteName)?.set(data, forKey: customLayoutDefaultsKey)
        invalidateLayoutCache()
    }

    static func restoreDefaultEditableLayout() {
        UserDefaults(suiteName: KeyboardState.appGroupSuiteName)?.removeObject(forKey: customLayoutDefaultsKey)
        invalidateLayoutCache()
    }
}

enum KeyCellPosition: String, CaseIterable, Codable, Identifiable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    var id: String { rawValue }

    var swipeDirection: SwipeDirection? {
        switch self {
        case .topLeft: return .topLeft
        case .top: return .top
        case .topRight: return .topRight
        case .left: return .left
        case .center: return nil
        case .right: return .right
        case .bottomLeft: return .bottomLeft
        case .bottom: return .bottom
        case .bottomRight: return .bottomRight
        }
    }

    init(direction: SwipeDirection) {
        switch direction {
        case .topLeft: self = .topLeft
        case .top: self = .top
        case .topRight: self = .topRight
        case .left: self = .left
        case .right: self = .right
        case .bottomLeft: self = .bottomLeft
        case .bottom: self = .bottom
        case .bottomRight: self = .bottomRight
        }
    }
}

struct EditableKeyConfig: Codable, Equatable {
    var cells: [KeyCellPosition: String]

    init(cells: [KeyCellPosition: String] = [:]) {
        self.cells = cells.filter { !$0.value.isEmpty }
    }

    init(keyConfig: KeyConfig) {
        var cells: [KeyCellPosition: String] = [:]
        if !keyConfig.tap.isEmpty {
            cells[.center] = keyConfig.tap
        }
        for (direction, value) in keyConfig.swipes where !value.isEmpty {
            cells[KeyCellPosition(direction: direction)] = value
        }
        self.cells = cells
    }

    var keyConfig: KeyConfig {
        var swipes: [SwipeDirection: String] = [:]
        for (position, value) in cells where position != .center && !value.isEmpty {
            if let direction = position.swipeDirection {
                swipes[direction] = value
            }
        }
        return KeyConfig(tap: cells[.center] ?? "", swipes: swipes)
    }

    func value(at position: KeyCellPosition) -> String {
        cells[position] ?? ""
    }

    mutating func setValue(_ value: String, at position: KeyCellPosition) {
        if value.isEmpty {
            cells.removeValue(forKey: position)
        } else {
            cells[position] = value
        }
    }
}

struct EditableKeyboardLayout: Codable, Equatable {
    var letterGrid: [[EditableKeyConfig]]
    var numberGrid: [[EditableKeyConfig]]
    var symbolOverlayGrid: [[EditableKeyConfig]]

    static var `default`: EditableKeyboardLayout {
        EditableKeyboardLayout(
            letterGrid: KeyboardLayoutData.letterGrid.map { row in row.map(EditableKeyConfig.init(keyConfig:)) },
            numberGrid: KeyboardLayoutData.numberGrid.map { row in row.map(EditableKeyConfig.init(keyConfig:)) },
            symbolOverlayGrid: KeyboardLayoutData.symbolOverlayGrid.map { row in row.map(EditableKeyConfig.init(keyConfig:)) }
        )
    }

    static var savedOrDefault: EditableKeyboardLayout {
        KeyboardLayoutData.savedEditableLayout() ?? .default
    }
}

// MARK: - Split Keyboard

/// When the keyboard shows a second half for the other thumb.
enum SplitKeyboardMode: String, CaseIterable, Identifiable {
    /// One keyboard, always.
    case off
    /// Split on large screens (iPad, unfolded foldables) in any orientation,
    /// and elsewhere only where both halves fit at full key size.
    case wideScreens
    /// Split on every screen and orientation, narrowing keys when needed.
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .wideScreens: return "Wide screens"
        case .always: return "Always"
        }
    }
}

/// The kind of screen the keyboard is on, so a split or single choice can be
/// remembered separately for each: a closed foldable's outer screen, the
/// unfolded inner screen upright, and the inner screen sideways each keep
/// their own. Works the same for any device (iPhone, iPad, foldable).
enum ScreenConfiguration: String, CaseIterable {
    case smallPortrait
    case smallLandscape
    case largePortrait
    case largeLandscape

    /// Screens whose short side reaches this are "large": iPads and unfolded
    /// foldables (669pt). Every other iPhone is under 450pt across.
    static let largeScreenMinimumShortSide: CGFloat = 600

    static func classify(screenSize: CGSize, bothSizeClassesRegular: Bool) -> ScreenConfiguration {
        let isLarge = bothSizeClassesRegular
            || min(screenSize.width, screenSize.height) >= largeScreenMinimumShortSide
        let isLandscape = screenSize.width > screenSize.height
        switch (isLarge, isLandscape) {
        case (false, false): return .smallPortrait
        case (false, true): return .smallLandscape
        case (true, false): return .largePortrait
        case (true, true): return .largeLandscape
        }
    }

    var isLarge: Bool { self == .largePortrait || self == .largeLandscape }
}

enum SplitPreference {
    /// The split mode to lay out with. A choice saved for this kind of screen
    /// (from the globe's out-and-back swipe) wins. Otherwise the app setting
    /// applies, and "Wide screens" splits every large screen, upright too,
    /// since there is room for a half under each thumb.
    static func effectiveMode(
        base: SplitKeyboardMode,
        configuration: ScreenConfiguration?,
        savedChoices: [String: Bool]
    ) -> SplitKeyboardMode {
        guard let configuration else { return base }
        if let split = savedChoices[configuration.rawValue] {
            return split ? .always : .off
        }
        if base == .wideScreens, configuration.isLarge {
            return .always
        }
        return base
    }
}

/// Key and rail widths for the chosen split mode at a given keyboard width.
struct SplitSizing: Equatable {
    let isSplit: Bool
    let keyWidth: CGFloat
    let railWidth: CGFloat

    /// Gap kept between the halves when "Always" narrows keys to fit both.
    static let minimumSqueezedGap: CGFloat = 12

    static func resolve(
        mode: SplitKeyboardMode,
        totalWidth: CGFloat,
        fullKeyWidth: CGFloat,
        fullRailWidth: CGFloat,
        spacing: CGFloat
    ) -> SplitSizing {
        let single = SplitSizing(isSplit: false, keyWidth: fullKeyWidth, railWidth: fullRailWidth)
        let full = SplitSizing(isSplit: true, keyWidth: fullKeyWidth, railWidth: fullRailWidth)
        // One half: three keys, two gaps, the gap before the rail, the rail.
        let fullHalf = fullKeyWidth * 3 + spacing * 3 + fullRailWidth
        let fitsFullSize = totalWidth >= fullHalf * 2 + fullKeyWidth * SplitMirrorLayout.minimumGapInKeys

        switch mode {
        case .off:
            return single
        case .wideScreens:
            return fitsFullSize ? full : single
        case .always:
            if fitsFullSize { return full }
            // Narrow keys so two halves (four key-wide columns each, rail
            // included) plus a small middle gap fill the width.
            let usable = totalWidth - minimumSqueezedGap - spacing * 6
            let keyWidth = max(min(fullKeyWidth, usable / 8), 1)
            let railRoom = usable / 2 - keyWidth * 3
            let railWidth = max(min(fullRailWidth, railRoom), keyWidth)
            return SplitSizing(isSplit: true, keyWidth: keyWidth, railWidth: railWidth)
        }
    }
}

/// Where the split keyboard's second half sits on a wide screen, and how its
/// touches map onto the primary half that owns the hit regions.
struct SplitMirrorLayout: Equatable {
    /// Left edge of the mirror's 3x3 grid.
    let gridX: CGFloat
    /// Left edge of the mirror's backspace rail.
    let railX: CGFloat
    let railWidth: CGFloat
    let spacing: CGFloat
    /// The mirror keeps its rail on the outer edge, opposite the primary's.
    let railOnRight: Bool
    /// Shift from a mirror grid / space-bar point to the primary one.
    let gridOffset: CGFloat
    /// Shift from a mirror rail / return-corner point to the primary one.
    let railOffset: CGFloat
    let minX: CGFloat
    let maxX: CGFloat

    /// In "Wide screens" mode the halves need at least this much clear space
    /// between them, in keys, so each half is still a full-size keyboard.
    static let minimumGapInKeys: CGFloat = 1.5

    static func make(
        enabled: Bool,
        totalWidth: CGFloat,
        keyWidth: CGFloat,
        spacing: CGFloat,
        primaryGridX: CGFloat,
        mainGridWidth: CGFloat,
        railWidth: CGFloat,
        primaryRailOnRight: Bool
    ) -> SplitMirrorLayout? {
        let halfWidth = mainGridWidth + spacing + railWidth
        // `SplitSizing` decides whether to split; this only refuses overlap.
        guard enabled,
              keyWidth > 0,
              totalWidth >= halfWidth * 2 else {
            return nil
        }

        let primaryRailX = primaryRailOnRight
            ? primaryGridX + mainGridWidth + spacing
            : primaryGridX - spacing - railWidth
        let mirrorRailOnRight = !primaryRailOnRight
        let mirrorMinX = mirrorRailOnRight ? totalWidth - halfWidth : 0
        let mirrorGridX = mirrorRailOnRight ? mirrorMinX : railWidth + spacing
        let mirrorRailX = mirrorRailOnRight ? totalWidth - railWidth : 0

        return SplitMirrorLayout(
            gridX: mirrorGridX,
            railX: mirrorRailX,
            railWidth: railWidth,
            spacing: spacing,
            railOnRight: mirrorRailOnRight,
            gridOffset: primaryGridX - mirrorGridX,
            railOffset: primaryRailX - mirrorRailX,
            minX: mirrorMinX,
            maxX: mirrorMinX + halfWidth
        )
    }

    /// The shift for a touch that lands at `x`, or 0 when it is not on the mirror.
    func offset(forX x: CGFloat) -> CGFloat {
        guard x >= minX, x <= maxX else { return 0 }
        let inRailColumn = railOnRight
            ? x >= railX - spacing / 2
            : x <= railX + railWidth + spacing / 2
        return inRailColumn ? railOffset : gridOffset
    }
}

// MARK: - Diacritics

/// Accented forms offered when a letter is held. Ordered by how often they
/// come up across the European languages that use them, most common first.
enum Diacritics {
    static let variants: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "d": ["ď", "đ"],
        "e": ["é", "è", "ê", "ë", "ē", "ė", "ę"],
        "g": ["ğ"],
        "i": ["í", "ì", "î", "ï", "ī", "į"],
        "l": ["ł", "ľ", "ĺ"],
        "n": ["ñ", "ń", "ň"],
        "o": ["ó", "ò", "ô", "ö", "õ", "ø", "œ", "ō"],
        "r": ["ř", "ŕ"],
        "s": ["ß", "ś", "š", "ş"],
        "t": ["ť", "ţ", "þ"],
        "u": ["ú", "ù", "û", "ü", "ū", "ů", "ű"],
        "y": ["ý", "ÿ"],
        "z": ["ž", "ź", "ż"],
    ]

    /// Accented forms of `letter`, in its case. Forms with no single-letter
    /// capital (ß) are left out of the uppercase list.
    static func variants(of letter: String) -> [String] {
        let lower = letter.lowercased()
        guard let forms = variants[lower] else { return [] }
        guard letter != lower else { return forms }
        return forms.map { $0.uppercased() }.filter { $0.count == 1 }
    }
}

/// The strip of choices shown while a letter is held, and which one the
/// finger is on. The finger picks by sliding sideways from where the strip
/// opened; lifting types the picked choice.
struct HoldPicker: Equatable {
    let choices: [String]
    /// Where the finger was when the strip opened, in keyboard coordinates.
    let anchor: CGPoint
    /// Choice under the finger when the strip opened.
    let initialIndex: Int
    let cellWidth: CGFloat
    private(set) var selectedIndex: Int

    init(choices: [String], anchor: CGPoint, initialIndex: Int = 0, cellWidth: CGFloat) {
        self.choices = choices
        self.anchor = anchor
        self.initialIndex = min(max(initialIndex, 0), max(choices.count - 1, 0))
        self.cellWidth = max(cellWidth, 1)
        self.selectedIndex = self.initialIndex
    }

    var selected: String? {
        choices.indices.contains(selectedIndex) ? choices[selectedIndex] : nil
    }

    /// Moves the selection with the finger. Returns true when it changed.
    @discardableResult
    mutating func track(_ point: CGPoint) -> Bool {
        let steps = Int(((point.x - anchor.x) / cellWidth).rounded())
        let index = min(max(initialIndex + steps, 0), choices.count - 1)
        guard index != selectedIndex else { return false }
        selectedIndex = index
        return true
    }

    /// Choices for holding a key's own letter: its number first, so a hold
    /// that lifts without sliding types the number as before, then the
    /// letter's accents.
    static func choicesForHeldKey(letter: String, number: String) -> [String] {
        [number] + Diacritics.variants(of: letter)
    }
}

// MARK: - Clipboard

/// What the paste key should do with what is on the clipboard. A keyboard
/// can only insert text into the field (`UITextDocumentProxy.insertText`),
/// so an image can't be pasted from here: iOS gives keyboards no way to hand
/// the app an image. The best we can do is say so and point at the system
/// Paste, which can.
enum ClipboardPaste: Equatable {
    case text(String)
    case notice(String)

    static let imageNotice = "Keyboards can't paste images. Tap the text box, then Paste."
    static let otherNotice = "That can't be pasted as text. Tap the text box, then Paste."
    static let emptyNotice = "The clipboard is empty."
    static let noAccessNotice = "Turn on Full Access for Tapeze to paste."

    static func resolve(
        hasFullAccess: Bool,
        string: String?,
        url: URL?,
        hasImages: Bool,
        itemCount: Int
    ) -> ClipboardPaste {
        if let string, !string.isEmpty { return .text(string) }
        if let url { return .text(url.absoluteString) }
        if !hasFullAccess { return .notice(noAccessNotice) }
        if hasImages { return .notice(imageNotice) }
        if itemCount == 0 { return .notice(emptyNotice) }
        return .notice(otherNotice)
    }
}

// MARK: - Tool Column

/// What the scrolling column beside the keys holds, top to bottom.
enum ToolColumnItem: Equatable, Hashable {
    case undo, redo, paste, copy
    case emoji(String)

    var symbol: String? {
        switch self {
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .paste: return "doc.on.clipboard"
        case .copy: return "doc.on.doc"
        case .emoji: return nil
        }
    }

    var caption: String? {
        switch self {
        case .undo: return "undo"
        case .redo: return "redo"
        case .paste: return "paste"
        case .copy: return "copy"
        case .emoji: return nil
        }
    }

    static func items(emoji: [String]) -> [ToolColumnItem] {
        [.undo, .redo, .paste, .copy] + emoji.map { .emoji($0) }
    }
}

/// Geometry of the tool column's wheel. Each row is one key row tall
/// (`rowHeight` = key height + gap), so at rest its cells line up with the
/// letter rows and the space bar beside them.
enum ToolColumnMetrics {
    static let width: CGFloat = 92
    /// Movement under which a touch on the column is a tap, not a scroll.
    static let tapSlop: CGFloat = 10
    /// How far a flick carries on, in seconds of its release speed.
    static let momentum: CGFloat = 0.22

    /// The last row has no gap below it.
    static func contentHeight(itemCount: Int, rowHeight: CGFloat, gap: CGFloat) -> CGFloat {
        max(CGFloat(itemCount) * rowHeight - gap, 0)
    }

    static func maxOffset(itemCount: Int, rowHeight: CGFloat, gap: CGFloat, height: CGFloat) -> CGFloat {
        let overflow = contentHeight(itemCount: itemCount, rowHeight: rowHeight, gap: gap) - height
        guard overflow > 0 else { return 0 }
        // Rest on whole rows at the end too, so the last screen stays aligned.
        return (overflow / rowHeight).rounded(.up) * rowHeight
    }

    /// Row under `y` (column coordinates) when the wheel is scrolled by `offset`.
    static func index(atY y: CGFloat, offset: CGFloat, rowHeight: CGFloat, itemCount: Int) -> Int? {
        let raw = (y + offset) / rowHeight
        guard raw >= 0 else { return nil }
        let index = Int(raw)
        return index < itemCount ? index : nil
    }

    /// Offset while dragging: past either end the wheel gives way slowly.
    static func dragged(_ offset: CGFloat, maxOffset: CGFloat) -> CGFloat {
        if offset < 0 { return offset / 3 }
        if offset > maxOffset { return maxOffset + (offset - maxOffset) / 3 }
        return offset
    }

    /// Where a released wheel comes to rest: carried on by its speed (points
    /// per second, positive scrolls further down the list), snapped to a whole
    /// row, and kept inside the content.
    static func resting(offset: CGFloat, velocity: CGFloat, rowHeight: CGFloat, maxOffset: CGFloat) -> CGFloat {
        let projected = offset + velocity * momentum
        let snapped = (projected / rowHeight).rounded() * rowHeight
        return min(max(snapped, 0), maxOffset)
    }
}

/// The emoji the tool column offers, most-picked first. The order is worked
/// out when the keyboard appears, never while it is up, so an emoji does not
/// move while a thumb is reaching for it.
enum EmojiUsage {
    static let defaults = ["😂", "❤️", "👍", "🙏", "😭", "🔥", "😊", "🎉", "👀", "✨", "😅", "💯"]
    static let countsKey = "toolColumnEmojiCounts"
    static let visibleCount = 12

    static func ranked(counts: [String: Int]) -> [String] {
        let pool = defaults + counts.keys.filter { !defaults.contains($0) }.sorted()
        let order = Dictionary(uniqueKeysWithValues: pool.enumerated().map { ($1, $0) })
        return pool
            .sorted { lhs, rhs in
                let l = counts[lhs] ?? 0, r = counts[rhs] ?? 0
                return l != r ? l > r : order[lhs]! < order[rhs]!
            }
            .prefix(visibleCount)
            .map { $0 }
    }
}

// MARK: - Edit History

/// Undo and redo for what this keyboard typed or deleted. iOS gives keyboards
/// no access to the app's own undo, so the keyboard keeps its own record and
/// replays it through the text proxy. Typing a word and the space after it is
/// one step, like the system keyboard; a backspace run within a word is one.
struct EditHistory: Equatable {
    enum Edit: Equatable {
        case inserted(String)
        case deleted(String)
    }

    static let limit = 50

    private(set) var undoStack: [Edit] = []
    private(set) var redoStack: [Edit] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Whether the last step is still being typed or deleted one character
    /// at a time, so the next character can join it. A paste or a word
    /// delete is a step of its own.
    private var stepIsOpen = false

    mutating func recordInsert(_ text: String) {
        guard !text.isEmpty else { return }
        redoStack.removeAll()
        if text.count == 1, stepIsOpen,
           case .inserted(let previous)? = undoStack.last,
           let last = previous.last, !last.isWhitespace {
            undoStack[undoStack.count - 1] = .inserted(previous + text)
        } else {
            push(.inserted(text))
        }
        stepIsOpen = text.count == 1
    }

    mutating func recordDelete(_ text: String) {
        guard !text.isEmpty else { return }
        redoStack.removeAll()
        if text.count == 1, stepIsOpen,
           case .deleted(let previous)? = undoStack.last,
           let first = previous.first,
           !(text.first!.isWhitespace && !first.isWhitespace) {
            undoStack[undoStack.count - 1] = .deleted(text + previous)
        } else {
            push(.deleted(text))
        }
        stepIsOpen = text.count == 1
    }

    /// The step to reverse, moved onto the redo stack.
    mutating func takeUndo() -> Edit? {
        stepIsOpen = false
        guard let edit = undoStack.popLast() else { return nil }
        redoStack.append(edit)
        return edit
    }

    /// The step to repeat, moved back onto the undo stack.
    mutating func takeRedo() -> Edit? {
        stepIsOpen = false
        guard let edit = redoStack.popLast() else { return nil }
        undoStack.append(edit)
        return edit
    }

    mutating func reset() {
        stepIsOpen = false
        undoStack.removeAll()
        redoStack.removeAll()
    }

    private mutating func push(_ edit: Edit) {
        undoStack.append(edit)
        if undoStack.count > Self.limit {
            undoStack.removeFirst(undoStack.count - Self.limit)
        }
    }
}
