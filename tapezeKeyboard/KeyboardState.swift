import SwiftUI
import Combine

// MARK: - Autocapitalization

/// Mirrors `UITextAutocapitalizationType` without importing UIKit here, so the
/// containing app can exercise the same rules in previews and tests.
enum AutocapitalizationMode {
    case none
    case words
    case sentences
    case allCharacters
}

// MARK: - Keyboard State

class KeyboardState: ObservableObject {
    static let appGroupSuiteName = "group.com.gm2211.tapeze"
    static let settingsDefaults = UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    static let showGestureTrailDefaultsKey = "showGestureTrail"
    static let keyCornerRadiusDefaultsKey = "keyCornerRadius"
    static let commandBarOnRightDefaultsKey = "commandBarOnRight"
    static let showCenterLabelsDefaultsKey = "showCenterLabels"
    static let keyboardHeightDefaultsKey = "keyboardHeight"
    static let themeDefaultsKey = "keyboardTheme"
    static let defaultKeyCornerRadius: CGFloat = 5
    static let defaultKeyboardHeight: CGFloat = 360
    private let persistsSettings: Bool

    @Published var currentLayer: KeyboardLayer = .letters
    @Published var isShifted: Bool = false
    @Published var isCapsLocked: Bool = false
    /// What the field being edited asks for. Driven by the text document proxy.
    var autocapitalizationMode: AutocapitalizationMode = .sentences
    /// True while `isShifted` was raised by autocapitalization rather than by
    /// the user. Auto shift yields to a manual one and can be dismissed with a
    /// single shift tap; a manual shift is never overwritten.
    private(set) var isShiftAutomatic: Bool = false
    @Published var keyboardHeight: CGFloat = KeyboardState.defaultKeyboardHeight {
        didSet {
            if persistsSettings {
                Self.settingsDefaults.set(Double(keyboardHeight), forKey: Self.keyboardHeightDefaultsKey)
            }
        }
    }
    @Published var commandBarOnRight: Bool = true {
        didSet {
            if persistsSettings {
                Self.settingsDefaults.set(commandBarOnRight, forKey: Self.commandBarOnRightDefaultsKey)
            }
        }
    }
    @Published var isFullWidth: Bool = true
    @Published var showCenterLabels: Bool = true {
        didSet {
            if persistsSettings {
                Self.settingsDefaults.set(showCenterLabels, forKey: Self.showCenterLabelsDefaultsKey)
            }
        }
    }
    @Published var isSymbolOverlayActive: Bool = false
    @Published var showSymbolLabels: Bool = true
    @Published var isURLField: Bool = false
    @Published var showGestureTrail: Bool {
        didSet {
            if persistsSettings {
                Self.settingsDefaults.set(showGestureTrail, forKey: Self.showGestureTrailDefaultsKey)
            }
        }
    }
    @Published var keyCornerRadius: CGFloat {
        didSet {
            if persistsSettings {
                Self.settingsDefaults.set(Double(keyCornerRadius), forKey: Self.keyCornerRadiusDefaultsKey)
            }
        }
    }
    @Published var selectedThemeID: String = KeyboardTheme.tapeze.id {
        didSet {
            if persistsSettings {
                Self.settingsDefaults.set(selectedThemeID, forKey: Self.themeDefaultsKey)
            }
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

    init(isPreview: Bool = false) {
        persistsSettings = !isPreview

        if isPreview || Self.settingsDefaults.object(forKey: Self.commandBarOnRightDefaultsKey) == nil {
            commandBarOnRight = true
        } else {
            commandBarOnRight = Self.settingsDefaults.bool(forKey: Self.commandBarOnRightDefaultsKey)
        }

        if Self.settingsDefaults.object(forKey: Self.showGestureTrailDefaultsKey) == nil {
            showGestureTrail = true
        } else {
            showGestureTrail = Self.settingsDefaults.bool(forKey: Self.showGestureTrailDefaultsKey)
        }

        if isPreview || Self.settingsDefaults.object(forKey: Self.showCenterLabelsDefaultsKey) == nil {
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

        if isPreview || Self.settingsDefaults.object(forKey: Self.keyboardHeightDefaultsKey) == nil {
            keyboardHeight = Self.defaultKeyboardHeight
        } else {
            keyboardHeight = min(maxHeight, max(minHeight, CGFloat(Self.settingsDefaults.double(forKey: Self.keyboardHeightDefaultsKey))))
        }
    }

    var theme: KeyboardTheme {
        KeyboardTheme.theme(for: selectedThemeID)
    }

    func reloadPersistedAppearanceSettings() {
        if Self.settingsDefaults.object(forKey: Self.showGestureTrailDefaultsKey) == nil {
            showGestureTrail = true
        } else {
            showGestureTrail = Self.settingsDefaults.bool(forKey: Self.showGestureTrailDefaultsKey)
        }

        if Self.settingsDefaults.object(forKey: Self.keyCornerRadiusDefaultsKey) == nil {
            keyCornerRadius = Self.defaultKeyCornerRadius
        } else {
            keyCornerRadius = CGFloat(Self.settingsDefaults.double(forKey: Self.keyCornerRadiusDefaultsKey))
        }

        selectedThemeID = Self.settingsDefaults.string(forKey: Self.themeDefaultsKey) ?? KeyboardTheme.tapeze.id

        if Self.settingsDefaults.object(forKey: Self.keyboardHeightDefaultsKey) == nil {
            keyboardHeight = Self.defaultKeyboardHeight
        } else {
            keyboardHeight = min(maxHeight, max(minHeight, CGFloat(Self.settingsDefaults.double(forKey: Self.keyboardHeightDefaultsKey))))
        }
    }

    func resetLearningPreview() {
        currentLayer = .letters
        isShifted = false
        isShiftAutomatic = false
        isCapsLocked = false
        isSymbolOverlayActive = false
        showSymbolLabels = true
        showCenterLabels = true
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
        } else if isShifted && isShiftAutomatic {
            // Dismissing a capital the keyboard offered by itself. Turning it
            // into caps lock here would punish the common "no, lowercase"
            // correction at the start of a sentence.
            isShifted = false
        } else if isShifted {
            isCapsLocked = true
        } else {
            isShifted = true
        }
        isShiftAutomatic = false
    }

    func afterCharacterInserted() {
        // Auto-unshift after typing (unless caps locked). The controller
        // re-evaluates autocapitalization right after this, so a capital that
        // is still due — the first letter of the next sentence — comes back.
        if isShifted && !isCapsLocked {
            isShifted = false
        }
        isShiftAutomatic = false
    }

    // MARK: - Autocapitalization

    /// Re-derives the automatic shift from the text before the cursor.
    /// `context` is the document context the input proxy reports; nil means the
    /// host gave us nothing, which for `.sentences` reads as an empty document.
    func updateAutocapitalization(before context: String?) {
        guard !isCapsLocked else { return }

        // A shift the user pressed is a deliberate choice for the next
        // character. Leave it alone until that character is typed.
        guard !(isShifted && !isShiftAutomatic) else { return }

        let shouldShift = Self.shouldAutocapitalize(context ?? "", mode: autocapitalizationMode)
        isShifted = shouldShift
        isShiftAutomatic = shouldShift
    }

    static func shouldAutocapitalize(_ context: String, mode: AutocapitalizationMode) -> Bool {
        switch mode {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words, .sentences:
            break
        }

        let characters = Array(context)
        var index = characters.count
        var sawSpace = false
        var sawNewline = false

        // Walk back over the whitespace the cursor is sitting after.
        while index > 0, characters[index - 1].isWhitespace {
            if characters[index - 1].isNewline {
                sawNewline = true
            } else {
                sawSpace = true
            }
            index -= 1
        }

        // Nothing but whitespace behind us: start of the document, or of a
        // paragraph the user opened with blank lines.
        if index == 0 {
            return true
        }

        // A newline always starts a fresh line, whatever ended the last one.
        if sawNewline {
            return true
        }

        if mode == .words {
            return sawSpace
        }

        // Sentences need the space too: "Hi." with the cursor tight against the
        // period is still mid-token, so a capital would be wrong there.
        guard sawSpace else { return false }

        // Step back over anything that closes a quotation or bracket, so
        // `He said "That's it." ` still reads as the end of a sentence.
        while index > 0, Self.sentenceClosingCharacters.contains(characters[index - 1]) {
            index -= 1
        }

        guard index > 0 else { return true }
        return Self.sentenceTerminators.contains(characters[index - 1])
    }

    private static let sentenceTerminators: Set<Character> = [
        ".", "!", "?", "\u{2026}", "\u{3002}", "\u{FF01}", "\u{FF1F}",
    ]

    private static let sentenceClosingCharacters: Set<Character> = [
        "\"", "'", ")", "]", "}", "\u{201D}", "\u{2019}", "\u{00BB}",
    ]

    func toggleSymbolsOnly() {
        if currentLayer == .letters {
            if isSymbolOverlayActive {
                isSymbolOverlayActive = false
                showSymbolLabels = false
            } else {
                isSymbolOverlayActive = true
                showSymbolLabels = true
            }
            return
        }

        currentLayer = .numbers
        showSymbolLabels.toggle()
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
