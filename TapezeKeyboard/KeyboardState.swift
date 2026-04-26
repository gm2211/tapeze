import SwiftUI
import Combine

// MARK: - Keyboard State

class KeyboardState: ObservableObject {
    static let showGestureTrailDefaultsKey = "showGestureTrail"

    @Published var currentLayer: KeyboardLayer = .letters
    @Published var isShifted: Bool = false
    @Published var isCapsLocked: Bool = false
    @Published var keyboardHeight: CGFloat = 280
    @Published var commandBarOnRight: Bool = true
    @Published var isFullWidth: Bool = true
    @Published var showCenterLabels: Bool = true
    @Published var isSymbolOverlayActive: Bool = false
    @Published var showGestureTrail: Bool {
        didSet {
            UserDefaults.standard.set(showGestureTrail, forKey: Self.showGestureTrailDefaultsKey)
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
        if UserDefaults.standard.object(forKey: Self.showGestureTrailDefaultsKey) == nil {
            showGestureTrail = true
        } else {
            showGestureTrail = UserDefaults.standard.bool(forKey: Self.showGestureTrailDefaultsKey)
        }
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
            if isSymbolOverlayActive {
                return KeyboardLayoutData.symbolOverlayGrid
            }
            return KeyboardLayoutData.letterGrid
        case .numbers:
            return KeyboardLayoutData.numberGrid
        case .symbolsOnly:
            // Same as numbers but we'll hide center labels in the view
            return KeyboardLayoutData.numberGrid
        }
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
