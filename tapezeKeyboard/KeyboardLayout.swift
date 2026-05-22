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
                .top: "w", .topRight: "'",
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
        // Shift indicator on key (1,2) top
        PersistentOverlay(position: GridPosition(row: 1, col: 2), direction: .top, action: .shift, displayLabel: "△"),
        // Tab on key (2,0) bottomRight
        PersistentOverlay(position: GridPosition(row: 2, col: 0), direction: .bottomRight, action: .tab, displayLabel: "⇥"),
        // Clipboard on key (0,0) topLeft
        PersistentOverlay(position: GridPosition(row: 0, col: 0), direction: .topLeft, action: .clipboard, displayLabel: "C"),
    ]

    /// ".com" shortcut on h key
    static let dotComPosition = GridPosition(row: 1, col: 0)

    static func activeLetterGrid() -> [[KeyConfig]] {
        savedEditableLayout()?.letterGrid.map { row in row.map(\.keyConfig) } ?? letterGrid
    }

    static func activeNumberGrid() -> [[KeyConfig]] {
        savedEditableLayout()?.numberGrid.map { row in row.map(\.keyConfig) } ?? numberGrid
    }

    static func activeSymbolOverlayGrid() -> [[KeyConfig]] {
        savedEditableLayout()?.symbolOverlayGrid.map { row in row.map(\.keyConfig) } ?? symbolOverlayGrid
    }

    static func savedEditableLayout() -> EditableKeyboardLayout? {
        guard let data = UserDefaults(suiteName: KeyboardState.appGroupSuiteName)?.data(forKey: customLayoutDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(EditableKeyboardLayout.self, from: data)
    }

    static func saveEditableLayout(_ layout: EditableKeyboardLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults(suiteName: KeyboardState.appGroupSuiteName)?.set(data, forKey: customLayoutDefaultsKey)
    }

    static func restoreDefaultEditableLayout() {
        UserDefaults(suiteName: KeyboardState.appGroupSuiteName)?.removeObject(forKey: customLayoutDefaultsKey)
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
