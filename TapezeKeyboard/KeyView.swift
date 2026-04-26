import SwiftUI

// MARK: - Theme Colors

struct KeyboardTheme {
    static let keyboardBackground = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let keyBackground = Color(red: 0.17, green: 0.24, blue: 0.31)       // #2C3E50
    static let commandBackground = Color(red: 0.75, green: 0.78, blue: 0.80)   // #BFC8CC
    static let spaceBackground = Color(red: 0.65, green: 0.68, blue: 0.70)     // #A6ADB2
    static let tapColor = Color(red: 0.78, green: 0.66, blue: 0.20)            // #C8A832 (golden)
    static let swipeColor = Color(red: 0.60, green: 0.66, blue: 0.72)          // #99A8B8 (light gray)
    static let specialTextColor = Color(red: 0.25, green: 0.30, blue: 0.35)    // dark gray
    static let keyBorder = Color(red: 0.35, green: 0.40, blue: 0.45)           // subtle border
    static let activeKeyBackground = Color(red: 0.25, green: 0.35, blue: 0.45) // highlight
}

// MARK: - Main Character Key View

struct CharacterKeyView: View {
    let config: KeyConfig
    let isActive: Bool
    let showCenter: Bool
    let showSwipes: Bool
    let isShifted: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? KeyboardTheme.activeKeyBackground : KeyboardTheme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(KeyboardTheme.keyBorder, lineWidth: 0.5)
                    )

                // Labels
                ZStack {
                    // Center tap label
                    if showCenter {
                        Text(displayText(config.tap))
                            .font(.system(size: centerFontSize(geo), weight: .bold, design: .rounded))
                            .foregroundColor(KeyboardTheme.tapColor)
                    }

                    if showSwipes {
                        // Swipe direction labels
                        ForEach(Array(config.swipes.keys), id: \.self) { dir in
                            if let char = config.swipes[dir] {
                                Text(displayText(char))
                                    .font(.system(size: swipeFontSize(geo), weight: .medium, design: .rounded))
                                    .foregroundColor(KeyboardTheme.swipeColor)
                                    .position(positionForDirection(dir, in: geo.size))
                            }
                        }
                    }
                }
            }
        }
    }

    private func displayText(_ text: String) -> String {
        if isShifted && text.count == 1 && text.first?.isLetter == true {
            return text.uppercased()
        }
        return text
    }

    private func centerFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.4
    }

    private func swipeFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.26
    }

    private func positionForDirection(_ dir: SwipeDirection, in size: CGSize) -> CGPoint {
        let xInset: CGFloat = 0.11
        let yInset: CGFloat = 0.13
        let xPositions: [CGFloat] = [xInset, 0.5, 1.0 - xInset]
        let yPositions: [CGFloat] = [yInset, 0.5, 1.0 - yInset]

        let col: Int
        let row: Int

        switch dir {
        case .topLeft:     col = 0; row = 0
        case .top:         col = 1; row = 0
        case .topRight:    col = 2; row = 0
        case .left:        col = 0; row = 1
        case .right:       col = 2; row = 1
        case .bottomLeft:  col = 0; row = 2
        case .bottom:      col = 1; row = 2
        case .bottomRight: col = 2; row = 2
        }

        return CGPoint(
            x: xPositions[col] * size.width,
            y: yPositions[row] * size.height
        )
    }
}

// MARK: - Command Key View

struct CommandKeyView: View {
    let config: KeyConfig
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? KeyboardTheme.activeKeyBackground : KeyboardTheme.commandBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(KeyboardTheme.keyBorder, lineWidth: 0.5)
                    )

                commandContent(size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func commandContent(size: CGSize) -> some View {
        switch config.specialAction {
        case .globe:
            Image(systemName: "globe")
                .font(.system(size: size.height * 0.4))
                .foregroundColor(KeyboardTheme.specialTextColor)

        case .backspace:
            Image(systemName: "delete.backward.fill")
                .font(.system(size: size.height * 0.3))
                .foregroundColor(KeyboardTheme.specialTextColor)

        case .enter:
            Image(systemName: "return")
                .font(.system(size: size.height * 0.4))
                .foregroundColor(KeyboardTheme.specialTextColor)

        case .toggleLayer:
            Text(config.displayLabel ?? "")
                .font(.system(size: size.height * 0.35, weight: .medium, design: .rounded))
                .foregroundColor(KeyboardTheme.specialTextColor)

        default:
            Text(config.displayLabel ?? config.tap)
                .font(.system(size: size.height * 0.3, weight: .medium, design: .rounded))
                .foregroundColor(KeyboardTheme.specialTextColor)
        }
    }
}

// MARK: - Space Bar View

struct SpaceBarView: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? KeyboardTheme.activeKeyBackground : KeyboardTheme.spaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(KeyboardTheme.keyBorder, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Number Bottom Row Key (0)

struct BottomNumberKeyView: View {
    let config: KeyConfig
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? KeyboardTheme.activeKeyBackground : KeyboardTheme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(KeyboardTheme.keyBorder, lineWidth: 0.5)
                    )

                Text(config.tap)
                    .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(KeyboardTheme.tapColor)
            }
        }
    }
}

// MARK: - Overlay Indicators

struct ShiftIndicatorView: View {
    let isShifted: Bool
    let isCapsLocked: Bool

    var body: some View {
        let symbolName = isCapsLocked ? "capslock.fill" : (isShifted ? "shift.fill" : "shift")
        Image(systemName: symbolName)
            .font(.system(size: 12))
            .foregroundColor(KeyboardTheme.tapColor)
    }
}
