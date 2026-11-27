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

// MARK: - Tool Column

/// What the scrolling column beside the keys holds, top to bottom.
enum ToolColumnItem: Equatable, Hashable {
    case undo, redo, paste, copy
    case emoji(String)
    /// Opens the full emoji picker. Always the last cell.
    case allEmoji

    var symbol: String? {
        switch self {
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .paste: return "doc.on.clipboard"
        case .copy: return "doc.on.doc"
        case .allEmoji: return "face.smiling"
        case .emoji: return nil
        }
    }

    var caption: String? {
        switch self {
        case .undo: return "undo"
        case .redo: return "redo"
        case .paste: return "paste"
        case .copy: return "copy"
        case .allEmoji: return "all emoji"
        case .emoji: return nil
        }
    }

    static func items(emoji: [String]) -> [ToolColumnItem] {
        ToolColumnConfig.default.items(recents: emoji)
    }
}

/// What the tool column shows, in what order, and what it does with spare
/// width. Chosen in the app's Left column screen and stored in the app group
/// so the keyboard can read it.
struct ToolColumnConfig: Codable, Equatable {
    enum Entry: String, Codable, CaseIterable, Identifiable {
        case undo, redo, paste, copy, pinnedEmoji, recentEmoji
        var id: String { rawValue }

        var title: String {
            switch self {
            case .undo: return "Undo"
            case .redo: return "Redo"
            case .paste: return "Paste"
            case .copy: return "Copy"
            case .pinnedEmoji: return "Pinned emoji"
            case .recentEmoji: return "Most-used emoji"
            }
        }

        var symbol: String {
            switch self {
            case .undo: return "arrow.uturn.backward"
            case .redo: return "arrow.uturn.forward"
            case .paste: return "doc.on.clipboard"
            case .copy: return "doc.on.doc"
            case .pinnedEmoji: return "star"
            case .recentEmoji: return "clock"
            }
        }
    }

    struct Slot: Codable, Equatable, Identifiable {
        var entry: Entry
        var isOn: Bool
        var id: String { entry.rawValue }
    }

    /// What the column does with width the keys leave over.
    enum SpareWidth: String, Codable, CaseIterable, Identifiable {
        case twoColumns, oneColumn, widen
        var id: String { rawValue }

        var title: String {
            switch self {
            case .twoColumns: return "Two columns when they fit"
            case .oneColumn: return "Always one column"
            case .widen: return "Widen the one column"
            }
        }
    }

    var slots: [Slot]
    var pinnedEmoji: [String]
    var recentCount: Int
    var spareWidth: SpareWidth

    static let defaultsKey = "toolColumnConfig"
    /// Opens the app's Left column screen.
    static let settingsURL = URL(string: "tapeze://left-column")!
    static let recentCountRange = 0...24

    static let `default` = ToolColumnConfig(
        slots: Entry.allCases.map { Slot(entry: $0, isOn: true) },
        pinnedEmoji: [],
        recentCount: 12,
        spareWidth: .twoColumns
    )

    /// Every entry exactly once, in the stored order, with any entry a newer
    /// version added appended at the end; counts kept in range.
    func normalized() -> ToolColumnConfig {
        var seen = Set<Entry>()
        var slots = self.slots.filter { seen.insert($0.entry).inserted }
        for entry in Entry.allCases where !seen.contains(entry) {
            slots.append(Slot(entry: entry, isOn: true))
        }
        var pinnedSeen = Set<String>()
        let pinned = pinnedEmoji.filter { !$0.isEmpty && pinnedSeen.insert($0).inserted }
        let count = min(max(recentCount, Self.recentCountRange.lowerBound), Self.recentCountRange.upperBound)
        return ToolColumnConfig(slots: slots, pinnedEmoji: pinned, recentCount: count, spareWidth: spareWidth)
    }

    static func load(from defaults: UserDefaults) -> ToolColumnConfig {
        guard let data = defaults.data(forKey: defaultsKey),
              let config = try? JSONDecoder().decode(ToolColumnConfig.self, from: data) else {
            return .default
        }
        return config.normalized()
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(normalized()) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    func isOn(_ entry: Entry) -> Bool {
        slots.first { $0.entry == entry }?.isOn ?? false
    }

    /// The column's cells: the chosen entries in order, recents without the
    /// pinned ones, and the All emoji button last.
    func items(recents: [String]) -> [ToolColumnItem] {
        var items: [ToolColumnItem] = []
        for slot in slots where slot.isOn {
            switch slot.entry {
            case .undo: items.append(.undo)
            case .redo: items.append(.redo)
            case .paste: items.append(.paste)
            case .copy: items.append(.copy)
            case .pinnedEmoji:
                items += pinnedEmoji.map { .emoji($0) }
            case .recentEmoji:
                let pinned = isOn(.pinnedEmoji) ? Set(pinnedEmoji) : []
                items += recents.filter { !pinned.contains($0) }.prefix(recentCount).map { .emoji($0) }
            }
        }
        items.append(.allEmoji)
        return items
    }
}

/// How wide the tool column is and how many cells sit side by side, given the
/// width the keys and the backspace rail leave over. Width the column can't
/// use becomes an empty stripe on its outer edge, never next to the rail.
enum ToolColumnLayout {
    /// Narrowest cell worth splitting into two columns for.
    static let minimumCellWidth: CGFloat = 60

    struct Resolved: Equatable {
        var columns: Int
        var width: CGFloat
        var stripe: CGFloat
    }

    static func resolve(available: CGFloat, mode: ToolColumnConfig.SpareWidth, gap: CGFloat) -> Resolved {
        let one = ToolColumnMetrics.width
        guard available > one else {
            return Resolved(columns: 1, width: max(available, 0), stripe: 0)
        }
        switch mode {
        case .widen:
            return Resolved(columns: 1, width: available, stripe: 0)
        case .oneColumn:
            return Resolved(columns: 1, width: one, stripe: available - one)
        case .twoColumns:
            let twoMinimum = minimumCellWidth * 2 + gap
            guard available >= twoMinimum else {
                return Resolved(columns: 1, width: one, stripe: available - one)
            }
            let width = min(available, one * 2 + gap)
            return Resolved(columns: 2, width: width, stripe: available - width)
        }
    }

    static func rowCount(itemCount: Int, columns: Int) -> Int {
        let columns = max(columns, 1)
        return (itemCount + columns - 1) / columns
    }

    /// Cell under a point in column coordinates, or nil past the last item.
    static func index(
        at point: CGPoint, offset: CGFloat, rowHeight: CGFloat,
        width: CGFloat, columns: Int, itemCount: Int
    ) -> Int? {
        let columns = max(columns, 1)
        guard let row = ToolColumnMetrics.index(
            atY: point.y, offset: offset, rowHeight: rowHeight,
            itemCount: rowCount(itemCount: itemCount, columns: columns)
        ) else { return nil }
        let column = min(max(Int(point.x / max(width / CGFloat(columns), 1)), 0), columns - 1)
        let index = row * columns + column
        return index < itemCount ? index : nil
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

    static func ranked(counts: [String: Int], limit: Int = visibleCount) -> [String] {
        let pool = defaults + counts.keys.filter { !defaults.contains($0) }.sorted()
        let order = Dictionary(uniqueKeysWithValues: pool.enumerated().map { ($1, $0) })
        return pool
            .sorted { lhs, rhs in
                let l = counts[lhs] ?? 0, r = counts[rhs] ?? 0
                return l != r ? l > r : order[lhs]! < order[rhs]!
            }
            .prefix(max(limit, 0))
            .map { $0 }
    }
}

// MARK: - Emoji picker

/// The emoji the full picker offers, by category. Built from Unicode ranges
/// and kept to code points the system draws as emoji, so the list follows the
/// iOS version without a hand-kept table.
enum EmojiCatalog {
    struct Category: Identifiable, Equatable {
        let id: String
        let icon: String
        let emoji: [String]
    }

    static let recentID = "recent"

    private static func build(_ ranges: [ClosedRange<UInt32>], extra: [String] = []) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for string in extra where seen.insert(string).inserted { result.append(string) }
        for range in ranges {
            for value in range {
                guard let scalar = Unicode.Scalar(value),
                      scalar.properties.isEmojiPresentation else { continue }
                let string = String(Character(scalar))
                if seen.insert(string).inserted { result.append(string) }
            }
        }
        return result
    }

    static let categories: [Category] = [
        Category(id: "smileys", icon: "😀", emoji: build([
            0x1F600...0x1F637, 0x1F641...0x1F644, 0x1F910...0x1F915, 0x1F917...0x1F92F,
            0x1F970...0x1F97A, 0x1F9D0...0x1F9D0, 0x1FAE0...0x1FAE8,
            0x1F44B...0x1F450, 0x1F64C...0x1F64F, 0x1F590...0x1F596, 0x1F918...0x1F91F,
            0x1F932...0x1F933, 0x1FAF0...0x1FAF8, 0x1F4AA...0x1F4AA,
            0x1F466...0x1F469, 0x1F474...0x1F478, 0x1F47C...0x1F47C, 0x1F9D1...0x1F9D3,
            0x1F648...0x1F64A, 0x1F638...0x1F640, 0x1F47B...0x1F47F, 0x1F480...0x1F480,
            0x1F4A9...0x1F4A9, 0x1F916...0x1F916,
        ])),
        Category(id: "nature", icon: "🐻", emoji: build([
            0x1F400...0x1F43F, 0x1F980...0x1F9AE, 0x1F330...0x1F344, 0x1F490...0x1F490,
            0x1F33F...0x1F33F, 0x1FAB0...0x1FABD, 0x1F30D...0x1F31F, 0x1F308...0x1F308,
            0x2B50...0x2B50, 0x26A1...0x26A1, 0x2744...0x2744, 0x1F30A...0x1F30A,
        ])),
        Category(id: "food", icon: "🍔", emoji: build([
            0x1F345...0x1F37F, 0x1F950...0x1F96F, 0x1F9C0...0x1F9CB, 0x2615...0x2615,
            0x1FAD0...0x1FADB,
        ])),
        Category(id: "activity", icon: "⚽️", emoji: build([
            0x26BD...0x26BE, 0x1F3C0...0x1F3CA, 0x1F3A3...0x1F3BD, 0x1F94A...0x1F94F,
            0x1F3AF...0x1F3AF, 0x1F396...0x1F39F, 0x1F947...0x1F949, 0x1F3CF...0x1F3D3,
        ])),
        Category(id: "travel", icon: "🚗", emoji: build([
            0x1F680...0x1F6C5, 0x1F6EB...0x1F6FC, 0x1F3E0...0x1F3F0, 0x1F5FB...0x1F5FF,
            0x26F0...0x26FD,
        ])),
        Category(id: "objects", icon: "💡", emoji: build([
            0x1F4A1...0x1F4A1, 0x1F4BB...0x1F4FC, 0x1F50B...0x1F52E, 0x231A...0x231B,
            0x23F0...0x23F3, 0x1F380...0x1F393, 0x1F9F0...0x1F9FF, 0x1FA70...0x1FA7C,
        ])),
        Category(id: "symbols", icon: "❤️", emoji: build([
            0x1F493...0x1F49F, 0x1F9E1...0x1F9E1, 0x1F90D...0x1F90E, 0x1F5A4...0x1F5A4,
            0x1FA75...0x1FA77, 0x1F4AF...0x1F4AF, 0x1F4A2...0x1F4A8, 0x1F4AB...0x1F4AB,
            0x2705...0x2705, 0x274C...0x274C, 0x2728...0x2728, 0x2753...0x2757,
            0x1F534...0x1F539, 0x1F7E0...0x1F7EB, 0x2795...0x2797,
        ], extra: ["❤️"])),
    ]
}

/// Where everything in the emoji picker sits: a scrolling grid with each
/// category starting on a new row, and a bar along the bottom with ABC, the
/// category tabs and backspace.
struct EmojiPickerLayout: Equatable {
    static let preferredCellSize: CGFloat = 42
    static let barHeight: CGFloat = 40
    static let abcWidth: CGFloat = 52
    static let backspaceWidth: CGFloat = 48

    enum BarTarget: Equatable {
        case abc, backspace, category(Int)
    }

    let size: CGSize
    let sections: [[String]]
    let columns: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    /// First row of each section.
    let sectionStartRows: [Int]
    let rowCount: Int

    init(size: CGSize, sections: [[String]]) {
        self.size = size
        self.sections = sections
        let columns = max(Int(size.width / Self.preferredCellSize), 1)
        self.columns = columns
        cellWidth = size.width / CGFloat(columns)
        cellHeight = Self.preferredCellSize
        var starts: [Int] = []
        var row = 0
        for section in sections {
            starts.append(row)
            row += max((section.count + columns - 1) / columns, 1)
        }
        sectionStartRows = starts
        rowCount = row
    }

    var gridHeight: CGFloat { max(size.height - Self.barHeight, 0) }

    var maxOffset: CGFloat {
        max(CGFloat(rowCount) * cellHeight - gridHeight, 0)
    }

    func offset(forSection index: Int) -> CGFloat {
        guard sectionStartRows.indices.contains(index) else { return 0 }
        return min(CGFloat(sectionStartRows[index]) * cellHeight, maxOffset)
    }

    /// The section showing at the top of the grid.
    func section(atOffset offset: CGFloat) -> Int {
        let row = Int((offset + cellHeight / 2) / cellHeight)
        return sectionStartRows.lastIndex { $0 <= row } ?? 0
    }

    /// Emoji under a point in picker coordinates, if the point is on the grid.
    func emoji(at point: CGPoint, offset: CGFloat) -> String? {
        guard point.y >= 0, point.y < gridHeight, point.x >= 0, point.x < size.width else { return nil }
        let row = Int((point.y + offset) / cellHeight)
        let column = min(Int(point.x / cellWidth), columns - 1)
        guard let section = sectionStartRows.lastIndex(where: { $0 <= row }) else { return nil }
        let index = (row - sectionStartRows[section]) * columns + column
        return sections[section].indices.contains(index) ? sections[section][index] : nil
    }

    func barTarget(at point: CGPoint) -> BarTarget? {
        guard point.y >= gridHeight else { return nil }
        if point.x < Self.abcWidth { return .abc }
        if point.x >= size.width - Self.backspaceWidth { return .backspace }
        let tabsWidth = size.width - Self.abcWidth - Self.backspaceWidth
        guard !sections.isEmpty, tabsWidth > 0 else { return nil }
        let index = Int((point.x - Self.abcWidth) / (tabsWidth / CGFloat(sections.count)))
        return .category(min(max(index, 0), sections.count - 1))
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
