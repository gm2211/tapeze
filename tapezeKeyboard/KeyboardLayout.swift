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
    /// Split only where both halves fit at full key size (iPad, landscape,
    /// unfolded foldables in landscape).
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
