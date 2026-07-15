import SwiftUI
import Combine

// MARK: - Keyboard State

class KeyboardState: ObservableObject {
    static let appGroupSuiteName = "group.com.gm2211.tapeze"
    static let settingsDefaults = UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    static let showGestureTrailDefaultsKey = "showGestureTrail"
    static let keyCornerRadiusDefaultsKey = "keyCornerRadius"
    static let commandBarOnRightDefaultsKey = "commandBarOnRight"
    static let showCenterLabelsDefaultsKey = "showCenterLabels"
    static let themeDefaultsKey = "keyboardTheme"
    static let defaultKeyCornerRadius: CGFloat = 5

    @Published var currentLayer: KeyboardLayer = .letters
    @Published var isShifted: Bool = false
    @Published var isCapsLocked: Bool = false
    @Published var keyboardHeight: CGFloat = 360
    @Published var commandBarOnRight: Bool = true {
        didSet {
            Self.settingsDefaults.set(commandBarOnRight, forKey: Self.commandBarOnRightDefaultsKey)
        }
    }
    @Published var isFullWidth: Bool = true
    @Published var showCenterLabels: Bool = true {
        didSet {
            Self.settingsDefaults.set(showCenterLabels, forKey: Self.showCenterLabelsDefaultsKey)
        }
    }
    @Published var isSymbolOverlayActive: Bool = false
    @Published var isURLField: Bool = false
    @Published var showGestureTrail: Bool {
        didSet {
            Self.settingsDefaults.set(showGestureTrail, forKey: Self.showGestureTrailDefaultsKey)
        }
    }
    @Published var keyCornerRadius: CGFloat {
        didSet {
            Self.settingsDefaults.set(Double(keyCornerRadius), forKey: Self.keyCornerRadiusDefaultsKey)
        }
    }
    @Published var selectedThemeID: String = KeyboardTheme.tapeze.id {
        didSet {
            Self.settingsDefaults.set(selectedThemeID, forKey: Self.themeDefaultsKey)
        }
    }

    // Gesture feedback
    @Published var activeKeyPosition: GridPosition? = nil
    @Published var swipeDirection: SwipeDirection? = nil
    @Published var gestureTrailPoints: [CGPoint] = []

    // Height constraints
    let minHeight: CGFloat = 200
    let maxHeight: CGFloat = 400
    let heightStep: CGFloat = 30

    init() {
        if Self.settingsDefaults.object(forKey: Self.commandBarOnRightDefaultsKey) == nil {
            commandBarOnRight = true
        } else {
            commandBarOnRight = Self.settingsDefaults.bool(forKey: Self.commandBarOnRightDefaultsKey)
        }

        if Self.settingsDefaults.object(forKey: Self.showGestureTrailDefaultsKey) == nil {
            showGestureTrail = true
        } else {
            showGestureTrail = Self.settingsDefaults.bool(forKey: Self.showGestureTrailDefaultsKey)
        }

        if Self.settingsDefaults.object(forKey: Self.showCenterLabelsDefaultsKey) == nil {
            showCenterLabels = true
        } else {
            showCenterLabels = Self.settingsDefaults.bool(forKey: Self.showCenterLabelsDefaultsKey)
        }

        if Self.settingsDefaults.object(forKey: Self.keyCornerRadiusDefaultsKey) == nil {
            keyCornerRadius = Self.defaultKeyCornerRadius
        } else {
            keyCornerRadius = CGFloat(Self.settingsDefaults.double(forKey: Self.keyCornerRadiusDefaultsKey))
        }

        selectedThemeID = Self.settingsDefaults.string(forKey: Self.themeDefaultsKey) ?? KeyboardTheme.tapeze.id
    }

    var theme: KeyboardTheme {
        KeyboardTheme.theme(for: selectedThemeID)
    }

    // MARK: - Actions

    func toggleLayer() {
        isSymbolOverlayActive = false

        switch currentLayer {
        case .letters:
            currentLayer = .numbers
        case .numbers:
            currentLayer = .letters
        case .symbolsOnly:
            currentLayer = .letters
        }
    }

    func toggleShift() {
        if isCapsLocked {
            isCapsLocked = false
            isShifted = false
        } else if isShifted {
            isCapsLocked = true
        } else {
            isShifted = true
        }
    }

    func afterCharacterInserted() {
        // Auto-unshift after typing (unless caps locked)
        if isShifted && !isCapsLocked {
            isShifted = false
        }
    }

    func toggleSymbolsOnly() {
        if currentLayer == .letters {
            isSymbolOverlayActive.toggle()
            return
        }

        if currentLayer == .symbolsOnly {
            currentLayer = .numbers
        } else if currentLayer == .numbers {
            currentLayer = .symbolsOnly
        }
    }

    func toggleCenterLabels() {
        showCenterLabels.toggle()
    }

    func increaseHeight() {
        keyboardHeight = min(maxHeight, keyboardHeight + heightStep)
    }

    func decreaseHeight() {
        keyboardHeight = max(minHeight, keyboardHeight - heightStep)
    }

    func toggleFullWidth() {
        isFullWidth.toggle()
    }

    func toggleCommandBarSide() {
        commandBarOnRight.toggle()
    }

    // MARK: - Current Grid

    var currentGrid: [[KeyConfig]] {
        switch currentLayer {
        case .letters:
            return KeyboardLayoutData.activeLetterGrid()
        case .numbers:
            return KeyboardLayoutData.activeNumberGrid()
        case .symbolsOnly:
            // Same as numbers but we'll hide center labels in the view
            return KeyboardLayoutData.activeNumberGrid()
        }
    }

    func refreshLayout() {
        objectWillChange.send()
    }

    var currentCommandBar: [KeyConfig] {
        KeyboardLayoutData.commandBar(for: currentLayer)
    }

    var currentBottomRow: [KeyConfig] {
        KeyboardLayoutData.bottomRow(for: currentLayer)
    }

    // MARK: - Apply Shift

    func applyCase(_ char: String) -> String {
        if isShifted || isCapsLocked {
            return char.uppercased()
        }
        return char
    }

    func applyUppercase(_ char: String) -> String {
        return char.uppercased()
    }
}
