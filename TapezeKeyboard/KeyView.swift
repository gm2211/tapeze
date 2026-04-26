import SwiftUI

// MARK: - Theme Colors

struct KeyboardTheme {
    static let keyboardBackground = Color(red: 0.08, green: 0.06, blue: 0.10)
    static let keyBackground = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let commandBackground = Color(red: 0.70, green: 0.70, blue: 0.70)
    static let spaceBackground = Color(red: 0.52, green: 0.53, blue: 0.52)
    static let tapColor = Color(red: 0.82, green: 0.86, blue: 1.0)
    static let swipeColor = Color(red: 0.96, green: 0.88, blue: 0.56)
    static let specialTextColor = Color(red: 0.03, green: 0.03, blue: 0.04)
    static let keyBorder = Color(red: 0.24, green: 0.24, blue: 0.26)
    static let activeKeyBackground = Color(red: 0.12, green: 0.10, blue: 0.16)
}

// MARK: - Main Character Key View

struct CharacterKeyView: View {
    let config: KeyConfig
    let isActive: Bool
    let showCenter: Bool
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
                            .font(.system(size: centerFontSize(geo), weight: .medium, design: .rounded))
                            .foregroundColor(KeyboardTheme.tapColor)
                    }

                    // Swipe direction labels
                    ForEach(Array(config.swipes.keys), id: \.self) { dir in
                        if let char = config.swipes[dir] {
                            Text(displayText(char))
                                .font(.system(size: swipeFontSize(geo), weight: .regular, design: .rounded))
                                .foregroundColor(KeyboardTheme.swipeColor)
                                .position(positionForDirection(dir, in: geo.size))
                        }
                    }
                }
                .padding(4)
            }
        }
    }

    private func displayText(_ text: String) -> String {
        if text.count == 1 && text.first?.isLetter == true {
            return text.uppercased()
        }
        return text
    }

    private func centerFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.46
    }

    private func swipeFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.21
    }

    private func positionForDirection(_ dir: SwipeDirection, in size: CGSize) -> CGPoint {
        let inset: CGFloat = 0.15
        let xPositions: [CGFloat] = [inset, 0.5, 1.0 - inset]
        let yPositions: [CGFloat] = [inset, 0.5, 1.0 - inset]

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
                .font(.system(size: size.height * 0.46, weight: .medium))
                .foregroundColor(KeyboardTheme.specialTextColor)

        case .backspace:
            Image(systemName: "delete.backward.fill")
                .font(.system(size: size.height * 0.34, weight: .medium))
                .foregroundColor(KeyboardTheme.specialTextColor)

        case .enter:
            Image(systemName: "return")
                .font(.system(size: size.height * 0.48, weight: .bold))
                .foregroundColor(KeyboardTheme.specialTextColor)

        case .toggleLayer:
            Text(config.displayLabel ?? "")
                .font(.system(size: size.height * 0.40, weight: .regular, design: .rounded))
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
                    .font(.system(size: min(geo.size.width, geo.size.height) * 0.46, weight: .medium, design: .rounded))
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
