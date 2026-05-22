import SwiftUI

// MARK: - Theme

struct KeyboardTheme: Identifiable {
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

    static let tapeze = KeyboardTheme(
        id: "tapeze",
        name: "tapeze",
        keyboardBackground: Color(red: 0.54, green: 0.59, blue: 0.60),
        emptyColumnBackground: Color(red: 0.47, green: 0.52, blue: 0.53),
        keyBackground: Color(red: 0.15, green: 0.21, blue: 0.27),
        commandBackground: Color(red: 0.16, green: 0.25, blue: 0.30),
        spaceBackground: Color(red: 0.74, green: 0.77, blue: 0.77),
        tapColor: Color(red: 0.50, green: 0.91, blue: 0.87),
        swipeColor: Color(red: 0.72, green: 0.80, blue: 0.88),
        specialTextColor: Color(red: 0.86, green: 0.95, blue: 0.96),
        keyBorder: Color(red: 0.11, green: 0.13, blue: 0.14),
        activeKeyBackground: Color(red: 0.15, green: 0.35, blue: 0.40),
        keyGradientTop: Color(red: 0.21, green: 0.30, blue: 0.37),
        keyGradientBottom: Color(red: 0.10, green: 0.15, blue: 0.20),
        commandGradientTop: Color(red: 0.30, green: 0.45, blue: 0.50),
        commandGradientBottom: Color(red: 0.16, green: 0.24, blue: 0.30),
        spaceGradientTop: Color(red: 0.27, green: 0.34, blue: 0.41),
        spaceGradientBottom: Color(red: 0.14, green: 0.19, blue: 0.25),
        keyBorderWidth: 1,
        innerHighlight: Color.white.opacity(0.11),
        keyShadowColor: Color.black.opacity(0.32),
        keyShadowRadius: 2.2,
        keyShadowYOffset: 1.4,
        labelShadowColor: Color.black.opacity(0.52),
        labelShadowRadius: 1.4,
        labelShadowYOffset: 2.1,
        textureOpacity: 0.04
    )

    static let all: [KeyboardTheme] = [.tapeze]

    static func theme(for id: String) -> KeyboardTheme {
        .tapeze
    }
}

enum KeySurfaceRole {
    case character
    case command
    case space
}

enum CommandVisualSide {
    case left
    case right
}

enum KeyCorner: Hashable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
}

private struct DiamondControlSurface: View {
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        let shape = DiamondKeyShape(cornerRadius: cornerRadius)
        let base = isActive ? theme.activeKeyBackground : theme.commandBackground
        let top = isActive ? theme.activeKeyBackground : (theme.commandGradientTop ?? base)
        let bottom = isActive ? theme.activeKeyBackground : (theme.commandGradientBottom ?? base)

        shape
            .fill(
                LinearGradient(
                    colors: [top, base, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: theme.keyShadowColor, radius: theme.keyShadowRadius + 0.5, x: 0, y: theme.keyShadowYOffset + 0.8)
            .overlay(
                shape
                    .strokeBorder(theme.innerHighlight, lineWidth: 1)
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
}

private struct FloatingControlSurface: View {
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        let shape = OctagonalKeyShape(cornerRadius: cornerRadius)
        let base = isActive ? theme.activeKeyBackground : theme.commandBackground
        let top = isActive ? theme.activeKeyBackground : (theme.commandGradientTop ?? base)
        let bottom = isActive ? theme.activeKeyBackground : (theme.commandGradientBottom ?? base)

        shape
            .fill(
                LinearGradient(
                    colors: [top, base, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: theme.keyShadowColor, radius: theme.keyShadowRadius + 0.4, x: 0, y: theme.keyShadowYOffset + 0.8)
            .overlay(
                shape
                    .strokeBorder(theme.innerHighlight, lineWidth: 1)
                    .blendMode(.screen)
            )
            .overlay(
                shape
                    .strokeBorder(theme.keyBorder.opacity(0.55), lineWidth: 0.8)
            )
    }
}

struct LatticeFillerDiamondView: View {
    let role: KeySurfaceRole
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        let shape = DiamondKeyShape(cornerRadius: cornerRadius)
        let base = baseColor
        let top = gradientTop ?? base
        let bottom = gradientBottom ?? base

        shape
            .fill(
                LinearGradient(
                    colors: [top, base, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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

private struct KeySurface: View {
    let role: KeySurfaceRole
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat
    let cutCorners: Set<KeyCorner>

    init(
        role: KeySurfaceRole,
        isActive: Bool,
        theme: KeyboardTheme,
        cornerRadius: CGFloat,
        cutCorners: Set<KeyCorner> = []
    ) {
        self.role = role
        self.isActive = isActive
        self.theme = theme
        self.cornerRadius = cornerRadius
        self.cutCorners = cutCorners
    }

    var body: some View {
        let shape = SelectiveCornerKeyShape(cornerRadius: cornerRadius, cutCorners: cutCorners)

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

struct SelectiveCornerKeyShape: InsettableShape {
    var cornerRadius: CGFloat
    var cutCorners: Set<KeyCorner>
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> SelectiveCornerKeyShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(min(r.width, r.height) * 0.30, min(r.width, r.height) * 0.5)
        var points: [CGPoint] = []

        if cutCorners.contains(.topLeft) {
            points.append(CGPoint(x: r.minX + cut, y: r.minY))
        } else {
            points.append(CGPoint(x: r.minX, y: r.minY))
        }

        if cutCorners.contains(.topRight) {
            points.append(CGPoint(x: r.maxX - cut, y: r.minY))
            points.append(CGPoint(x: r.maxX, y: r.minY + cut))
        } else {
            points.append(CGPoint(x: r.maxX, y: r.minY))
        }

        if cutCorners.contains(.bottomRight) {
            points.append(CGPoint(x: r.maxX, y: r.maxY - cut))
            points.append(CGPoint(x: r.maxX - cut, y: r.maxY))
        } else {
            points.append(CGPoint(x: r.maxX, y: r.maxY))
        }

        if cutCorners.contains(.bottomLeft) {
            points.append(CGPoint(x: r.minX + cut, y: r.maxY))
            points.append(CGPoint(x: r.minX, y: r.maxY - cut))
        } else {
            points.append(CGPoint(x: r.minX, y: r.maxY))
        }

        if cutCorners.contains(.topLeft) {
            points.append(CGPoint(x: r.minX, y: r.minY + cut))
        }

        let radius = min(max(cornerRadius, 0), min(r.width, r.height) * 0.10)
        guard radius > 0 else {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }

        var path = Path()
        for index in points.indices {
            let current = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let start = point(from: current, toward: previous, distance: radius)
            let end = point(from: current, toward: next, distance: radius)

            if index == points.startIndex {
                path.move(to: start)
            } else {
                path.addLine(to: start)
            }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }

    private func point(from origin: CGPoint, toward target: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let scale = min(distance / length, 0.45)
        return CGPoint(x: origin.x + dx * scale, y: origin.y + dy * scale)
    }
}

struct DiamondKeyShape: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> DiamondKeyShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let points = [
            CGPoint(x: r.midX, y: r.minY),
            CGPoint(x: r.maxX, y: r.midY),
            CGPoint(x: r.midX, y: r.maxY),
            CGPoint(x: r.minX, y: r.midY)
        ]
        let radius = min(max(cornerRadius, 0), min(r.width, r.height) * 0.09)
        guard radius > 0 else {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }

        var path = Path()
        for index in points.indices {
            let current = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let start = point(from: current, toward: previous, distance: radius)
            let end = point(from: current, toward: next, distance: radius)

            if index == points.startIndex {
                path.move(to: start)
            } else {
                path.addLine(to: start)
            }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }

    private func point(from origin: CGPoint, toward target: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let scale = min(distance / length, 0.45)
        return CGPoint(x: origin.x + dx * scale, y: origin.y + dy * scale)
    }
}

struct OctagonalKeyShape: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> OctagonalKeyShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let w = insetRect.width
        let h = insetRect.height
        let sideCut = min(min(w, h) * 0.30, min(w, h) * 0.5)
        let points = [
            CGPoint(x: insetRect.minX + sideCut, y: insetRect.minY),
            CGPoint(x: insetRect.maxX - sideCut, y: insetRect.minY),
            CGPoint(x: insetRect.maxX, y: insetRect.minY + sideCut),
            CGPoint(x: insetRect.maxX, y: insetRect.maxY - sideCut),
            CGPoint(x: insetRect.maxX - sideCut, y: insetRect.maxY),
            CGPoint(x: insetRect.minX + sideCut, y: insetRect.maxY),
            CGPoint(x: insetRect.minX, y: insetRect.maxY - sideCut),
            CGPoint(x: insetRect.minX, y: insetRect.minY + sideCut)
        ]
        let maxRadius = min(w, h) * 0.10
        let radius = min(max(cornerRadius, 0), maxRadius)

        guard radius > 0 else {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }

        var path = Path()
        for index in points.indices {
            let current = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let start = point(from: current, toward: previous, distance: radius)
            let end = point(from: current, toward: next, distance: radius)

            if index == points.startIndex {
                path.move(to: start)
            } else {
                path.addLine(to: start)
            }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }

    private func point(from origin: CGPoint, toward target: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let scale = min(distance / length, 0.45)
        return CGPoint(x: origin.x + dx * scale, y: origin.y + dy * scale)
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

extension View {
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

    func commandLabelDepth(for theme: KeyboardTheme) -> some View {
        self
            .shadow(
                color: theme.id == KeyboardTheme.tapeze.id ? Color.white.opacity(0.22) : .clear,
                radius: 0.25,
                x: -0.25,
                y: -0.35
            )
            .shadow(
                color: theme.id == KeyboardTheme.tapeze.id ? Color.black.opacity(0.24) : theme.labelShadowColor,
                radius: theme.id == KeyboardTheme.tapeze.id ? 1.0 : theme.labelShadowRadius,
                x: 0,
                y: theme.id == KeyboardTheme.tapeze.id ? 1.0 : theme.labelShadowYOffset
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
    let cutCorners: Set<KeyCorner>

    var body: some View {
        GeometryReader { geo in
            ZStack {
                KeySurface(role: .character, isActive: isActive, theme: theme, cornerRadius: cornerRadius, cutCorners: cutCorners)

                ZStack {
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
                        ForEach(swipeLabelDirections, id: \.self) { dir in
                            if let char = displayedSwipeLabels[dir] {
                                Text(displayText(char))
                                    .font(.system(size: swipeFontSize(geo), weight: .medium, design: .rounded))
                                    .foregroundColor(theme.swipeColor)
                                    .labelDepth(for: theme)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(
                                        width: swipeLabelSize(geo),
                                        height: swipeLabelSize(geo)
                                    )
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
        min(geo.size.width, geo.size.height) * 0.40
    }

    private func swipeFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.20
    }

    private func symbolOverlayFontSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.15
    }

    private func swipeLabelSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.26
    }

    private func symbolOverlayLabelSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width, geo.size.height) * 0.24
    }

    private func positionForDirection(_ dir: SwipeDirection, in size: CGSize) -> CGPoint {
        let xInset: CGFloat = 0.28
        let topInset: CGFloat = 0.25
        let bottomInset: CGFloat = 0.18
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
        let xInset: CGFloat = 0.28
        let topInset: CGFloat = 0.25
        let bottomInset: CGFloat = 0.18
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

struct DiamondCommandKeyView: View {
    let config: KeyConfig
    let isActive: Bool
    let isShifted: Bool
    let isCapsLocked: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    init(
        config: KeyConfig,
        isActive: Bool,
        isShifted: Bool = false,
        isCapsLocked: Bool = false,
        theme: KeyboardTheme,
        cornerRadius: CGFloat
    ) {
        self.config = config
        self.isActive = isActive
        self.isShifted = isShifted
        self.isCapsLocked = isCapsLocked
        self.theme = theme
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DiamondControlSurface(isActive: isActive, theme: theme, cornerRadius: cornerRadius)
                commandContent(size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func commandContent(size: CGSize) -> some View {
        switch config.specialAction {
        case .globe:
            Image(systemName: "globe")
                .font(.system(size: size.height * 0.34))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)

        case .enter:
            Image(systemName: "return")
                .font(.system(size: size.height * 0.34))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)

        case .shift:
            Image(systemName: isCapsLocked ? "capslock.fill" : (isShifted ? "shift.fill" : "shift"))
                .font(.system(size: size.height * 0.34))
                .foregroundColor(theme.tapColor)
                .commandLabelDepth(for: theme)

        case .toggleLayer:
            Text(config.displayLabel ?? "")
                .font(.system(size: size.height * 0.28, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)
                .minimumScaleFactor(0.65)
                .lineLimit(1)

        default:
            Text(config.displayLabel ?? config.tap)
                .font(.system(size: size.height * 0.26, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)
        }
    }
}

struct DeleteColumnKeyView: View {
    let isActive: Bool
    let side: CommandVisualSide
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        let shape = DeleteColumnFangShape(side: side, cornerRadius: cornerRadius)
        let base = isActive ? theme.activeKeyBackground : theme.commandBackground
        let top = isActive ? theme.activeKeyBackground : (theme.commandGradientTop ?? base)
        let bottom = isActive ? theme.activeKeyBackground : (theme.commandGradientBottom ?? base)

        shape
            .fill(
                LinearGradient(
                    colors: [top, base, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: theme.keyShadowColor, radius: theme.keyShadowRadius + 0.4, x: 0, y: theme.keyShadowYOffset + 0.4)
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
}

struct DeleteColumnFangShape: InsettableShape {
    var side: CommandVisualSide
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> DeleteColumnFangShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(max(cornerRadius, 0), min(r.width, r.height) * 0.10)
        return Path(roundedRect: r, cornerSize: CGSize(width: radius, height: radius))
    }
}

struct CommandKeyView: View {
    let config: KeyConfig
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if config.specialAction == .backspace {
                    DeleteFangSurface(isActive: isActive, theme: theme, cornerRadius: cornerRadius)
                    commandContent(size: geo.size)
                } else {
                    FloatingControlSurface(isActive: isActive, theme: theme, cornerRadius: cornerRadius)
                        .frame(width: min(geo.size.width, geo.size.height) * 0.82, height: min(geo.size.width, geo.size.height) * 0.82)
                    commandContent(size: CGSize(width: min(geo.size.width, geo.size.height) * 0.82, height: min(geo.size.width, geo.size.height) * 0.82))
                }
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
                .commandLabelDepth(for: theme)

        case .backspace:
            Image(systemName: "delete.backward.fill")
                .font(.system(size: size.height * 0.3))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)

        case .enter:
            Image(systemName: "return")
                .font(.system(size: size.height * 0.4))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)

        case .toggleLayer:
            Text(config.displayLabel ?? "")
                .font(.system(size: size.height * 0.35, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)

        default:
            Text(config.displayLabel ?? config.tap)
                .font(.system(size: size.height * 0.3, weight: .medium, design: .rounded))
                .foregroundColor(theme.specialTextColor)
                .commandLabelDepth(for: theme)
        }
    }
}

// MARK: - Space Bar View

private struct DeleteFangSurface: View {
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        let shape = DeleteFangShape(cornerRadius: cornerRadius)
        let base = isActive ? theme.activeKeyBackground : theme.commandBackground
        let top = isActive ? theme.activeKeyBackground : (theme.commandGradientTop ?? base)
        let bottom = isActive ? theme.activeKeyBackground : (theme.commandGradientBottom ?? base)

        shape
            .fill(
                LinearGradient(
                    colors: [top, base, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
}

private struct DeleteFangShape: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> DeleteFangShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(r.width * 0.32, r.height * 0.22)
        let midY = r.midY
        let points = [
            CGPoint(x: r.minX + cut, y: r.minY),
            CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.maxY),
            CGPoint(x: r.minX + cut, y: r.maxY),
            CGPoint(x: r.minX, y: midY)
        ]

        let radius = min(max(cornerRadius, 0), min(r.width, r.height) * 0.10)
        guard radius > 0 else {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }

        var path = Path()
        for index in points.indices {
            let current = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let start = point(from: current, toward: previous, distance: radius)
            let end = point(from: current, toward: next, distance: radius)

            if index == points.startIndex {
                path.move(to: start)
            } else {
                path.addLine(to: start)
            }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }

    private func point(from origin: CGPoint, toward target: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let scale = min(distance / length, 0.45)
        return CGPoint(x: origin.x + dx * scale, y: origin.y + dy * scale)
    }
}

struct SpaceBarView: View {
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat
    let fangCenters: [CGFloat]

    init(isActive: Bool, theme: KeyboardTheme, cornerRadius: CGFloat, fangCenters: [CGFloat] = []) {
        self.isActive = isActive
        self.theme = theme
        self.cornerRadius = cornerRadius
        self.fangCenters = fangCenters
    }

    var body: some View {
        GeometryReader { geo in
            SpaceFangSurface(isActive: isActive, theme: theme, cornerRadius: cornerRadius, fangCenters: fangCenters)
        }
    }
}

private struct SpaceFangSurface: View {
    let isActive: Bool
    let theme: KeyboardTheme
    let cornerRadius: CGFloat
    let fangCenters: [CGFloat]

    var body: some View {
        let shape = SpaceFangShape(cornerRadius: cornerRadius, fangCenters: fangCenters)
        let base = isActive ? theme.activeKeyBackground : theme.spaceBackground
        let top = isActive ? theme.activeKeyBackground : (theme.spaceGradientTop ?? base)
        let bottom = isActive ? theme.activeKeyBackground : (theme.spaceGradientBottom ?? base)

        shape
            .fill(
                LinearGradient(
                    colors: [top, base, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
}

struct SpaceFangShape: InsettableShape {
    var cornerRadius: CGFloat
    var fangCenters: [CGFloat]
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> SpaceFangShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(max(cornerRadius, 0), r.height * 0.12)
        return Path(roundedRect: r, cornerSize: CGSize(width: radius, height: radius))
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
