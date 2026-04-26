import SwiftUI

// MARK: - Theme

struct KeyboardTheme: Identifiable {
    static let defaultsKey = "keyboardTheme"

    let id: String
    let name: String
    let keyboardBackground: Color
    let keyBackground: Color
    let commandBackground: Color
    let spaceBackground: Color
    let tapColor: Color
    let swipeColor: Color
    let specialTextColor: Color
    let keyBorder: Color
    let activeKeyBackground: Color

    static let classic = KeyboardTheme(
        id: "classic",
        name: "Classic",
        keyboardBackground: Color(red: 0.12, green: 0.12, blue: 0.14),
        keyBackground: Color(red: 0.17, green: 0.24, blue: 0.31),
        commandBackground: Color(red: 0.75, green: 0.78, blue: 0.80),
        spaceBackground: Color(red: 0.65, green: 0.68, blue: 0.70),
        tapColor: Color(red: 0.78, green: 0.66, blue: 0.20),
        swipeColor: Color(red: 0.60, green: 0.66, blue: 0.72),
        specialTextColor: Color(red: 0.25, green: 0.30, blue: 0.35),
        keyBorder: Color(red: 0.35, green: 0.40, blue: 0.45),
        activeKeyBackground: Color(red: 0.25, green: 0.35, blue: 0.45)
    )

    static let liquidGlass = KeyboardTheme(
        id: "liquidGlass",
        name: "Liquid Glass",
        keyboardBackground: Color(red: 0.62, green: 0.65, blue: 0.68).opacity(0.58),
        keyBackground: Color(red: 0.96, green: 0.97, blue: 0.97).opacity(0.74),
        commandBackground: Color(red: 0.91, green: 0.92, blue: 0.93).opacity(0.82),
        spaceBackground: Color(red: 0.73, green: 0.75, blue: 0.77).opacity(0.58),
        tapColor: Color(red: 0.06, green: 0.08, blue: 0.10),
        swipeColor: Color(red: 0.35, green: 0.38, blue: 0.42),
        specialTextColor: Color(red: 0.08, green: 0.09, blue: 0.11),
        keyBorder: Color.white.opacity(0.92),
        activeKeyBackground: Color(red: 1.00, green: 1.00, blue: 1.00).opacity(0.92)
    )

    static let graphite = KeyboardTheme(
        id: "graphite",
        name: "Graphite",
        keyboardBackground: Color(red: 0.08, green: 0.09, blue: 0.11),
        keyBackground: Color(red: 0.14, green: 0.16, blue: 0.19),
        commandBackground: Color(red: 0.58, green: 0.61, blue: 0.66),
        spaceBackground: Color(red: 0.42, green: 0.45, blue: 0.49),
        tapColor: Color(red: 0.93, green: 0.78, blue: 0.16),
        swipeColor: Color(red: 0.78, green: 0.82, blue: 0.88),
        specialTextColor: Color(red: 0.10, green: 0.13, blue: 0.17),
        keyBorder: Color(red: 0.28, green: 0.31, blue: 0.36),
        activeKeyBackground: Color(red: 0.22, green: 0.25, blue: 0.30)
    )

    static let aurora = KeyboardTheme(
        id: "aurora",
        name: "Aurora",
        keyboardBackground: Color(red: 0.07, green: 0.13, blue: 0.15),
        keyBackground: Color(red: 0.08, green: 0.23, blue: 0.27),
        commandBackground: Color(red: 0.72, green: 0.82, blue: 0.82),
        spaceBackground: Color(red: 0.52, green: 0.63, blue: 0.64),
        tapColor: Color(red: 0.93, green: 0.76, blue: 0.23),
        swipeColor: Color(red: 0.60, green: 0.83, blue: 0.82),
        specialTextColor: Color(red: 0.08, green: 0.15, blue: 0.18),
        keyBorder: Color(red: 0.15, green: 0.38, blue: 0.43),
        activeKeyBackground: Color(red: 0.12, green: 0.33, blue: 0.38)
    )

    static let roseQuartz = KeyboardTheme(
        id: "roseQuartz",
        name: "Rose Quartz",
        keyboardBackground: Color(red: 0.21, green: 0.16, blue: 0.19),
        keyBackground: Color(red: 0.33, green: 0.24, blue: 0.29),
        commandBackground: Color(red: 0.84, green: 0.77, blue: 0.79),
        spaceBackground: Color(red: 0.66, green: 0.58, blue: 0.61),
        tapColor: Color(red: 0.98, green: 0.79, blue: 0.37),
        swipeColor: Color(red: 0.86, green: 0.72, blue: 0.80),
        specialTextColor: Color(red: 0.24, green: 0.19, blue: 0.23),
        keyBorder: Color(red: 0.45, green: 0.34, blue: 0.40),
        activeKeyBackground: Color(red: 0.43, green: 0.30, blue: 0.38)
    )

    static let all: [KeyboardTheme] = [.classic, .liquidGlass, .graphite, .aurora, .roseQuartz]

    static func theme(for id: String) -> KeyboardTheme {
        all.first { $0.id == id } ?? .classic
    }
}

// MARK: - Main Character Key View

struct CharacterKeyView: View {
    let config: KeyConfig
    let letterSwipeLabels: [SwipeDirection: String]?
    let isActive: Bool
    let showCenter: Bool
    let showSwipes: Bool
    let showSymbolOverlay: Bool
    let isShifted: Bool
    let theme: KeyboardTheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? theme.activeKeyBackground : theme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(theme.keyBorder, lineWidth: 0.5)
                    )

                // Labels
                ZStack {
                    // Center tap label
                    if showCenter {
                        Text(displayText(config.tap))
                            .font(.system(size: centerFontSize(geo), weight: .bold, design: .rounded))
                            .foregroundColor(theme.tapColor)
                    }

                    if showSymbolOverlay {
                        ForEach(Array(config.swipes.keys), id: \.self) { dir in
                            if let char = config.swipes[dir] {
                                Text(char)
                                    .font(.system(size: symbolOverlayFontSize(geo), weight: .medium, design: .rounded))
                                    .foregroundColor(theme.swipeColor.opacity(0.62))
                                    .position(symbolOverlayPositionForDirection(dir, in: geo.size))
                            }
                        }
                    }

                    if showSwipes {
                        // Swipe direction labels
                        ForEach(Array(displayedSwipeLabels.keys), id: \.self) { dir in
                            if let char = displayedSwipeLabels[dir] {
                                Text(displayText(char))
                                    .font(.system(size: swipeFontSize(geo), weight: .medium, design: .rounded))
                                    .foregroundColor(theme.swipeColor)
                                    .position(positionForDirection(dir, in: geo.size))
                            }
                        }
                    }
                }
            }
        }
    }

    private var displayedSwipeLabels: [SwipeDirection: String] {
        letterSwipeLabels ?? config.swipes
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

    private func symbolOverlayFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.20
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

    private func symbolOverlayPositionForDirection(_ dir: SwipeDirection, in size: CGSize) -> CGPoint {
        let xInset: CGFloat = 0.06
        let yInset: CGFloat = 0.08
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
    let theme: KeyboardTheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? theme.activeKeyBackground : theme.commandBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(theme.keyBorder, lineWidth: 0.5)
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
                .foregroundColor(theme.specialTextColor)

        case .backspace:
            Image(systemName: "delete.backward.fill")
                .font(.system(size: size.height * 0.3))
                .foregroundColor(theme.specialTextColor)

        case .enter:
            Image(systemName: "return")
                .font(.system(size: size.height * 0.4))
                .foregroundColor(theme.specialTextColor)

        case .toggleLayer:
            Text(config.displayLabel ?? "")
                .font(.system(size: size.height * 0.35, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)

        default:
            Text(config.displayLabel ?? config.tap)
                .font(.system(size: size.height * 0.3, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
        }
    }
}

// MARK: - Space Bar View

struct SpaceBarView: View {
    let isActive: Bool
    let theme: KeyboardTheme

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? theme.activeKeyBackground : theme.spaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(theme.keyBorder, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Number Bottom Row Key (0)

struct BottomNumberKeyView: View {
    let config: KeyConfig
    let isActive: Bool
    let theme: KeyboardTheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? theme.activeKeyBackground : theme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(theme.keyBorder, lineWidth: 0.5)
                    )

                Text(config.tap)
                    .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(theme.tapColor)
            }
        }
    }
}

// MARK: - Overlay Indicators

struct ShiftIndicatorView: View {
    let isShifted: Bool
    let isCapsLocked: Bool
    let theme: KeyboardTheme

    var body: some View {
        let symbolName = isCapsLocked ? "capslock.fill" : (isShifted ? "shift.fill" : "shift")
        Image(systemName: symbolName)
            .font(.system(size: 12))
            .foregroundColor(theme.tapColor)
    }
}
