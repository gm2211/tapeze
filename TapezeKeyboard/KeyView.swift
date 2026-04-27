import SwiftUI

// MARK: - Theme

struct KeyboardTheme: Identifiable {
    static let defaultsKey = "keyboardTheme"

    let id: String
    let name: String
    let keyboardBackground: Color
    let emptyColumnBackground: Color
    let keyBackground: Color
    let commandBackground: Color
    let spaceBackground: Color
    let tapColor: Color
    let swipeColor: Color
    let specialTextColor: Color
    let keyBorder: Color
    let activeKeyBackground: Color
    let keyGradientTop: Color?
    let keyGradientBottom: Color?
    let commandGradientTop: Color?
    let commandGradientBottom: Color?
    let spaceGradientTop: Color?
    let spaceGradientBottom: Color?
    let keyBorderWidth: CGFloat
    let innerHighlight: Color
    let keyShadowColor: Color
    let keyShadowRadius: CGFloat
    let keyShadowYOffset: CGFloat
    let labelShadowColor: Color
    let labelShadowRadius: CGFloat
    let labelShadowYOffset: CGFloat
    let textureOpacity: CGFloat

    init(
        id: String,
        name: String,
        keyboardBackground: Color,
        emptyColumnBackground: Color,
        keyBackground: Color,
        commandBackground: Color,
        spaceBackground: Color,
        tapColor: Color,
        swipeColor: Color,
        specialTextColor: Color,
        keyBorder: Color,
        activeKeyBackground: Color,
        keyGradientTop: Color? = nil,
        keyGradientBottom: Color? = nil,
        commandGradientTop: Color? = nil,
        commandGradientBottom: Color? = nil,
        spaceGradientTop: Color? = nil,
        spaceGradientBottom: Color? = nil,
        keyBorderWidth: CGFloat = 0.5,
        innerHighlight: Color = .clear,
        keyShadowColor: Color = .clear,
        keyShadowRadius: CGFloat = 0,
        keyShadowYOffset: CGFloat = 0,
        labelShadowColor: Color = .clear,
        labelShadowRadius: CGFloat = 0,
        labelShadowYOffset: CGFloat = 0,
        textureOpacity: CGFloat = 0
    ) {
        self.id = id
        self.name = name
        self.keyboardBackground = keyboardBackground
        self.emptyColumnBackground = emptyColumnBackground
        self.keyBackground = keyBackground
        self.commandBackground = commandBackground
        self.spaceBackground = spaceBackground
        self.tapColor = tapColor
        self.swipeColor = swipeColor
        self.specialTextColor = specialTextColor
        self.keyBorder = keyBorder
        self.activeKeyBackground = activeKeyBackground
        self.keyGradientTop = keyGradientTop
        self.keyGradientBottom = keyGradientBottom
        self.commandGradientTop = commandGradientTop
        self.commandGradientBottom = commandGradientBottom
        self.spaceGradientTop = spaceGradientTop
        self.spaceGradientBottom = spaceGradientBottom
        self.keyBorderWidth = keyBorderWidth
        self.innerHighlight = innerHighlight
        self.keyShadowColor = keyShadowColor
        self.keyShadowRadius = keyShadowRadius
        self.keyShadowYOffset = keyShadowYOffset
        self.labelShadowColor = labelShadowColor
        self.labelShadowRadius = labelShadowRadius
        self.labelShadowYOffset = labelShadowYOffset
        self.textureOpacity = textureOpacity
    }

    static let classic = KeyboardTheme(
        id: "classic",
        name: "Classic",
        keyboardBackground: Color(red: 0.12, green: 0.12, blue: 0.14),
        emptyColumnBackground: Color(red: 0.18, green: 0.16, blue: 0.18),
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
        keyboardBackground: Color.white.opacity(0.10),
        emptyColumnBackground: Color.white.opacity(0.06),
        keyBackground: Color.white.opacity(0.36),
        commandBackground: Color.white.opacity(0.46),
        spaceBackground: Color.white.opacity(0.24),
        tapColor: Color(red: 0.08, green: 0.10, blue: 0.12),
        swipeColor: Color(red: 0.30, green: 0.34, blue: 0.39),
        specialTextColor: Color(red: 0.08, green: 0.10, blue: 0.12),
        keyBorder: Color.white.opacity(0.78),
        activeKeyBackground: Color.white.opacity(0.64)
    )

    static let graphite = KeyboardTheme(
        id: "graphite",
        name: "Graphite",
        keyboardBackground: Color(red: 0.08, green: 0.09, blue: 0.11),
        emptyColumnBackground: Color(red: 0.18, green: 0.16, blue: 0.13),
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
        emptyColumnBackground: Color(red: 0.18, green: 0.12, blue: 0.20),
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
        emptyColumnBackground: Color(red: 0.16, green: 0.20, blue: 0.19),
        keyBackground: Color(red: 0.33, green: 0.24, blue: 0.29),
        commandBackground: Color(red: 0.84, green: 0.77, blue: 0.79),
        spaceBackground: Color(red: 0.66, green: 0.58, blue: 0.61),
        tapColor: Color(red: 0.98, green: 0.79, blue: 0.37),
        swipeColor: Color(red: 0.86, green: 0.72, blue: 0.80),
        specialTextColor: Color(red: 0.24, green: 0.19, blue: 0.23),
        keyBorder: Color(red: 0.45, green: 0.34, blue: 0.40),
        activeKeyBackground: Color(red: 0.43, green: 0.30, blue: 0.38)
    )

    static let tapeze = KeyboardTheme(
        id: "tapeze",
        name: "Tapeze",
        keyboardBackground: Color(red: 0.14, green: 0.17, blue: 0.20),
        emptyColumnBackground: Color(red: 0.18, green: 0.19, blue: 0.20),
        keyBackground: Color(red: 0.18, green: 0.23, blue: 0.28),
        commandBackground: Color(red: 0.57, green: 0.61, blue: 0.65),
        spaceBackground: Color(red: 0.48, green: 0.52, blue: 0.56),
        tapColor: Color(red: 0.86, green: 0.68, blue: 0.24),
        swipeColor: Color(red: 0.58, green: 0.65, blue: 0.72),
        specialTextColor: Color(red: 0.17, green: 0.21, blue: 0.26),
        keyBorder: Color(red: 0.30, green: 0.36, blue: 0.42),
        activeKeyBackground: Color(red: 0.24, green: 0.30, blue: 0.36),
        keyGradientTop: Color(red: 0.24, green: 0.29, blue: 0.34),
        keyGradientBottom: Color(red: 0.15, green: 0.19, blue: 0.24),
        commandGradientTop: Color(red: 0.66, green: 0.70, blue: 0.74),
        commandGradientBottom: Color(red: 0.47, green: 0.51, blue: 0.55),
        spaceGradientTop: Color(red: 0.56, green: 0.60, blue: 0.63),
        spaceGradientBottom: Color(red: 0.42, green: 0.46, blue: 0.50),
        keyBorderWidth: 1,
        innerHighlight: Color.white.opacity(0.09),
        keyShadowColor: Color.black.opacity(0.24),
        keyShadowRadius: 2.2,
        keyShadowYOffset: 1.4,
        labelShadowColor: Color.black.opacity(0.58),
        labelShadowRadius: 1.9,
        labelShadowYOffset: 2.1,
        textureOpacity: 0.055
    )

    static let all: [KeyboardTheme] = [.classic, .tapeze, .liquidGlass, .graphite, .aurora, .roseQuartz]

    static func theme(for id: String) -> KeyboardTheme {
        all.first { $0.id == id } ?? .classic
    }
}

private enum KeySurfaceRole {
    case character
    case command
    case space
}

private struct KeySurface: View {
    let role: KeySurfaceRole
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(fillStyle)
            .shadow(color: theme.keyShadowColor, radius: theme.keyShadowRadius, x: 0, y: theme.keyShadowYOffset)
            .overlay(
                shape
                    .strokeBorder(theme.innerHighlight, lineWidth: max(theme.keyBorderWidth, 1))
                    .blendMode(.screen)
                    .padding(theme.keyBorderWidth)
            )
            .overlay(
                shape
                    .strokeBorder(theme.keyBorder, lineWidth: theme.keyBorderWidth)
            )
            .overlay {
                if theme.textureOpacity > 0 {
                    KeycapTexture(opacity: theme.textureOpacity)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
    }

    private var fillStyle: LinearGradient {
        let base = isActive ? theme.activeKeyBackground : baseColor
        let top = isActive ? theme.activeKeyBackground : (gradientTop ?? base)
        let bottom = isActive ? theme.activeKeyBackground : (gradientBottom ?? base)

        return LinearGradient(
            colors: [top, base, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var baseColor: Color {
        switch role {
        case .character:
            return theme.keyBackground
        case .command:
            return theme.commandBackground
        case .space:
            return theme.spaceBackground
        }
    }

    private var gradientTop: Color? {
        switch role {
        case .character:
            return theme.keyGradientTop
        case .command:
            return theme.commandGradientTop
        case .space:
            return theme.spaceGradientTop
        }
    }

    private var gradientBottom: Color? {
        switch role {
        case .character:
            return theme.keyGradientBottom
        case .command:
            return theme.commandGradientBottom
        case .space:
            return theme.spaceGradientBottom
        }
    }
}

private struct KeycapTexture: View {
    let opacity: CGFloat

    var body: some View {
        Canvas { context, size in
            for index in 0..<90 {
                let xSeed = CGFloat((index * 37) % 101) / 100
                let ySeed = CGFloat((index * 53) % 101) / 100
                let diameter = CGFloat((index % 3) + 1) * 0.45
                let rect = CGRect(
                    x: xSeed * size.width,
                    y: ySeed * size.height,
                    width: diameter,
                    height: diameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
        }
    }
}

private extension View {
    func labelDepth(for theme: KeyboardTheme) -> some View {
        self
            .shadow(
                color: theme.id == KeyboardTheme.tapeze.id ? Color.white.opacity(0.18) : .clear,
                radius: 0.35,
                x: -0.35,
                y: -0.45
            )
            .shadow(
                color: theme.labelShadowColor,
                radius: theme.labelShadowRadius,
                x: 0,
                y: theme.labelShadowYOffset
            )
            .shadow(
                color: theme.id == KeyboardTheme.tapeze.id ? Color.black.opacity(0.24) : .clear,
                radius: 0.45,
                x: 0,
                y: 0.8
            )
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
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                KeySurface(role: .character, isActive: isActive, theme: theme, cornerRadius: cornerRadius)

                // Labels
                ZStack {
                    // Center tap label
                    if showCenter {
                        Text(displayText(config.tap))
                            .font(.system(size: centerFontSize(geo), weight: .bold, design: .rounded))
                            .foregroundColor(theme.tapColor)
                            .labelDepth(for: theme)
                    }

                    if showSymbolOverlay {
                        ForEach(symbolOverlayDirections, id: \.self) { dir in
                            if let char = displayedSymbolOverlayLabels[dir] {
                                Text(char)
                                    .font(.system(size: symbolOverlayFontSize(geo), weight: .medium, design: .rounded))
                                    .foregroundColor(theme.swipeColor.opacity(0.62))
                                    .labelDepth(for: theme)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                    .frame(
                                        width: symbolOverlayLabelSize(geo),
                                        height: symbolOverlayLabelSize(geo)
                                    )
                                    .position(symbolOverlayPositionForDirection(dir, in: geo.size))
                            }
                        }
                    }

                    if showSwipes {
                        // Swipe direction labels
                        ForEach(swipeLabelDirections, id: \.self) { dir in
                            if let char = displayedSwipeLabels[dir] {
                                Text(displayText(char))
                                    .font(.system(size: swipeFontSize(geo), weight: .medium, design: .rounded))
                                    .foregroundColor(theme.swipeColor)
                                    .labelDepth(for: theme)
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

    private var displayedSymbolOverlayLabels: [SwipeDirection: String] {
        guard let letterSwipeLabels else { return config.swipes }
        return config.swipes.filter { direction, symbol in
            letterSwipeLabels[direction] != symbol
        }
    }

    private var swipeLabelDirections: [SwipeDirection] {
        SwipeDirection.allCases.filter { displayedSwipeLabels[$0] != nil }
    }

    private var symbolOverlayDirections: [SwipeDirection] {
        SwipeDirection.allCases.filter { displayedSymbolOverlayLabels[$0] != nil }
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
        min(geo.size.width, geo.size.height) * 0.17
    }

    private func symbolOverlayLabelSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.24
    }

    private func positionForDirection(_ dir: SwipeDirection, in size: CGSize) -> CGPoint {
        let xInset: CGFloat = 0.11
        let topInset: CGFloat = 0.13
        let bottomInset: CGFloat = 0.19
        let xPositions: [CGFloat] = [xInset, 0.5, 1.0 - xInset]
        let yPositions: [CGFloat] = [topInset, 0.5, 1.0 - bottomInset]

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
        let xInset: CGFloat = 0.13
        let topInset: CGFloat = 0.15
        let bottomInset: CGFloat = 0.22
        let xPositions: [CGFloat] = [xInset, 0.5, 1.0 - xInset]
        let yPositions: [CGFloat] = [topInset, 0.5, 1.0 - bottomInset]

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
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                KeySurface(role: .command, isActive: isActive, theme: theme, cornerRadius: cornerRadius)

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
                .labelDepth(for: theme)

        case .backspace:
            Image(systemName: "delete.backward.fill")
                .font(.system(size: size.height * 0.3))
                .foregroundColor(theme.specialTextColor)
                .labelDepth(for: theme)

        case .enter:
            Image(systemName: "return")
                .font(.system(size: size.height * 0.4))
                .foregroundColor(theme.specialTextColor)
                .labelDepth(for: theme)

        case .toggleLayer:
            Text(config.displayLabel ?? "")
                .font(.system(size: size.height * 0.35, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
                .labelDepth(for: theme)

        default:
            Text(config.displayLabel ?? config.tap)
                .font(.system(size: size.height * 0.3, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
                .labelDepth(for: theme)
        }
    }
}

// MARK: - Space Bar View

struct SpaceBarView: View {
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            KeySurface(role: .space, isActive: isActive, theme: theme, cornerRadius: cornerRadius)
        }
    }
}

// MARK: - Number Bottom Row Key (0)

struct BottomNumberKeyView: View {
    let config: KeyConfig
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                KeySurface(role: .character, isActive: isActive, theme: theme, cornerRadius: cornerRadius)

                Text(config.tap)
                    .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(theme.tapColor)
                    .labelDepth(for: theme)
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
            .labelDepth(for: theme)
    }
}
