import SwiftUI
import UIKit

// MARK: - Main Keyboard View

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    let onCharacter: (String) -> Void
    let onBackspace: () -> Void
    let onDeleteWord: () -> Void
    let onDeleteLine: () -> Void
    let onEnter: () -> Void
    let onNextKeyboard: (() -> Void)?

    @State private var keyRegions: [GridPosition: CGRect] = [:]
    @State private var spaceBarRegion: CGRect = .zero
    @State private var globeRegion: CGRect = .zero
    @State private var gestureEngine = GestureEngine()

    private let gridRows = 3
    private let gridCols = 3
    private let spacing: CGFloat = 2
    private let maxTrailDisplayPoints = 42
    private let minTrailPointDistance: CGFloat = 7

    var body: some View {
        GeometryReader { outerGeo in
            let totalWidth = max(outerGeo.size.width, 1)
            let totalHeight = max(outerGeo.size.height, 1)
            let mainRowHeight = (totalHeight - spacing * 3) / 4
            let squareCommandColWidth = mainRowHeight
            let squareMainGridWidth = mainRowHeight * CGFloat(gridCols) + spacing * CGFloat(gridCols - 1)
            let squareLayoutWidth = squareMainGridWidth + squareCommandColWidth + spacing
            let shouldDisableCompact = !state.isFullWidth && squareLayoutWidth > totalWidth
            let usesFullWidth = state.isFullWidth || shouldDisableCompact
            let maxEmptyColumnWidth = mainRowHeight
            let squareLayoutWithEmptyColumnWidth = squareLayoutWidth + spacing + maxEmptyColumnWidth
            let fullWidthKeySide = max((totalWidth - spacing * CGFloat(gridCols)) / CGFloat(gridCols + 1), 1)
            let keySide: CGFloat = {
                if usesFullWidth {
                    return fullWidthKeySide
                }
                if !usesFullWidth && totalWidth > squareLayoutWithEmptyColumnWidth {
                    return max((totalWidth - maxEmptyColumnWidth - spacing * 4) / CGFloat(gridCols + 1), 1)
                }
                return squareLayoutWidth <= totalWidth
                    ? mainRowHeight
                    : fullWidthKeySide
            }()
            let emptyColumnWidth: CGFloat = {
                guard !usesFullWidth else { return 0 }
                if totalWidth > squareLayoutWithEmptyColumnWidth {
                    return maxEmptyColumnWidth
                }
                return min(maxEmptyColumnWidth, max(totalWidth - squareLayoutWidth - spacing, 0))
            }()
            let commandColWidth = keySide
            let mainGridWidth = keySide * CGFloat(gridCols) + spacing * CGFloat(gridCols - 1)
            let mainGridHeight = mainRowHeight * 3 + spacing * 2
            let bottomRowHeight = mainRowHeight
            let layoutWidth = usesFullWidth
                ? totalWidth
                : mainGridWidth + commandColWidth + spacing + (emptyColumnWidth > 0 ? emptyColumnWidth + spacing : 0)

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    // Command bar on left (if configured)
                    if !state.commandBarOnRight {
                        commandBar(width: commandColWidth, totalHeight: mainGridHeight)
                    }

                    // Spacer sits opposite the command bar in compact mode.
                    if !usesFullWidth && state.commandBarOnRight && emptyColumnWidth > 0 {
                        compactEmptyColumn(width: emptyColumnWidth)
                    }

                    // Main 3x3 grid
                    mainGrid(width: mainGridWidth, height: mainGridHeight, rowHeight: mainRowHeight)

                    if !usesFullWidth && !state.commandBarOnRight && emptyColumnWidth > 0 {
                        compactEmptyColumn(width: emptyColumnWidth)
                    }

                    // Command bar on right (if configured)
                    if state.commandBarOnRight {
                        commandBar(width: commandColWidth, totalHeight: mainGridHeight)
                    }
                }
                .frame(width: layoutWidth, alignment: state.commandBarOnRight ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: state.commandBarOnRight ? .trailing : .leading)

                // Bottom row: spacebar plus return key.
                HStack(spacing: spacing) {
                    if !state.commandBarOnRight {
                        enterKey(width: commandColWidth, height: bottomRowHeight)
                    }

                    if !usesFullWidth && state.commandBarOnRight && emptyColumnWidth > 0 {
                        compactEmptyColumn(width: emptyColumnWidth)
                    }

                    bottomRow(width: mainGridWidth, height: bottomRowHeight)

                    if !usesFullWidth && !state.commandBarOnRight && emptyColumnWidth > 0 {
                        compactEmptyColumn(width: emptyColumnWidth)
                    }

                    if state.commandBarOnRight {
                        enterKey(width: commandColWidth, height: bottomRowHeight)
                    }
                }
                .frame(width: layoutWidth, alignment: state.commandBarOnRight ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: state.commandBarOnRight ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: totalHeight)
            .background(state.theme.keyboardBackground)
            .onAppear {
                if shouldDisableCompact {
                    state.isFullWidth = true
                }
            }
            .onChange(of: shouldDisableCompact) { disableCompact in
                if disableCompact {
                    state.isFullWidth = true
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboard"))
                    .onChanged { value in
                        if !gestureEngine.hasActiveGesture {
                            gestureEngine.touchBegan(at: value.startLocation)
                            resetGestureTrail(at: value.startLocation)
                        }
                        gestureEngine.touchMoved(to: value.location)
                        if state.showGestureTrail {
                            appendGestureTrailPoint(value.location)
                        } else {
                            state.gestureTrailPoints = []
                        }
                        updateActiveKey(at: value.location)
                    }
                    .onEnded { value in
                        if !gestureEngine.hasActiveGesture {
                            gestureEngine.touchBegan(at: value.startLocation)
                            resetGestureTrail(at: value.startLocation)
                        }
                        if state.showGestureTrail {
                            appendGestureTrailPoint(value.location, force: true)
                        }
                        let result = gestureEngine.touchEnded(at: value.location)
                        handleGestureResult(result)
                        state.activeKeyPosition = nil
                        state.swipeDirection = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            state.gestureTrailPoints = []
                        }
                    }
            )
            .overlay {
                if state.showGestureTrail && !state.gestureTrailPoints.isEmpty {
                    GestureTrailView(points: state.gestureTrailPoints, theme: state.theme)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "keyboard")
        }
        .frame(height: state.keyboardHeight)
        .onAppear {
            gestureEngine.updateKeyRegions(keyRegions)
            gestureEngine.updateSpaceBarRegion(spaceBarRegion)
            gestureEngine.updateGlobeRegion(globeRegion)
        }
    }

    // MARK: - Main 3x3 Grid

    private func compactEmptyColumn(width: CGFloat) -> some View {
        state.theme.emptyColumnBackground
            .frame(width: width)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func mainGrid(width: CGFloat, height: CGFloat, rowHeight: CGFloat) -> some View {
        let colWidth = max((width - spacing * CGFloat(gridCols - 1)) / CGFloat(gridCols), 1)
        let grid = state.currentGrid
        let isSymbolOverlay = state.currentLayer == .letters && state.isSymbolOverlayActive
        let showCenter = state.currentLayer != .symbolsOnly && state.showCenterLabels
        let showSwipes = state.currentLayer != .letters || state.showCenterLabels

        VStack(spacing: spacing) {
            ForEach(0..<gridRows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridCols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        let config = grid[row][col]
                        let letterSwipeLabels = isSymbolOverlay ? KeyboardLayoutData.letterGrid[row][col].swipes : nil
                        let isActive = state.activeKeyPosition == pos

                        CharacterKeyView(
                            config: config,
                            letterSwipeLabels: letterSwipeLabels,
                            isActive: isActive,
                            showCenter: showCenter,
                            showSwipes: showSwipes,
                            showSymbolOverlay: isSymbolOverlay,
                            isShifted: state.isShifted || state.isCapsLocked,
                            theme: state.theme,
                            cornerRadius: state.keyCornerRadius
                        )
                        .frame(width: colWidth, height: rowHeight)
                        .overlay(
                            // Persistent overlays
                            overlaysForKey(at: pos, size: CGSize(width: colWidth, height: rowHeight))
                        )
                        .background(
                            GeometryReader { geo in
                                let frame = geo.frame(in: .named("keyboard"))
                                Color.clear.onAppear {
                                    keyRegions[pos] = frame
                                    gestureEngine.updateKeyRegions(keyRegions)
                                }
                                .onChange(of: frame) { newFrame in
                                    keyRegions[pos] = newFrame
                                    gestureEngine.updateKeyRegions(keyRegions)
                                }
                            }
                        )
                    }
                }
            }
        }
        .frame(width: width)
    }

    // MARK: - Command Bar

    @ViewBuilder
    private func commandBar(width: CGFloat, totalHeight: CGFloat) -> some View {
        let commands = state.currentCommandBar
        let rowHeight = (totalHeight - spacing * CGFloat(commands.count - 1)) / CGFloat(commands.count)

        VStack(spacing: spacing) {
            ForEach(0..<commands.count, id: \.self) { idx in
                let config = commands[idx]
                let commandPos = GridPosition(row: idx, col: state.commandBarOnRight ? 3 : -1)

                CommandKeyView(
                    config: config,
                    isActive: state.activeKeyPosition == commandPos,
                    theme: state.theme,
                    cornerRadius: state.keyCornerRadius
                )
                .frame(width: width, height: rowHeight)
                .background(
                    GeometryReader { geo in
                        let frame = geo.frame(in: .named("keyboard"))
                        Color.clear.onAppear {
                            if config.specialAction == .globe {
                                globeRegion = frame
                                gestureEngine.updateGlobeRegion(globeRegion)
                            }
                            keyRegions[commandPos] = frame
                            gestureEngine.updateKeyRegions(keyRegions)
                        }
                        .onChange(of: frame) { newFrame in
                            if config.specialAction == .globe {
                                globeRegion = newFrame
                                gestureEngine.updateGlobeRegion(globeRegion)
                            }
                            keyRegions[commandPos] = newFrame
                            gestureEngine.updateKeyRegions(keyRegions)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Bottom Row

    @ViewBuilder
    private func bottomRow(width: CGFloat, height: CGFloat) -> some View {
        if state.currentLayer == .letters {
            SpaceBarView(
                isActive: state.activeKeyPosition == GridPosition(row: 3, col: 0),
                theme: state.theme,
                cornerRadius: state.keyCornerRadius
            )
                .frame(width: width, height: height)
                .background(
                    GeometryReader { geo in
                        let frame = geo.frame(in: .named("keyboard"))
                        Color.clear.onAppear {
                            spaceBarRegion = frame
                            gestureEngine.updateSpaceBarRegion(spaceBarRegion)
                        }
                        .onChange(of: frame) { newFrame in
                            spaceBarRegion = newFrame
                            gestureEngine.updateSpaceBarRegion(spaceBarRegion)
                        }
                    }
                )
        } else {
            let parts = state.currentBottomRow
            HStack(spacing: spacing) {
                ForEach(0..<parts.count, id: \.self) { idx in
                    let config = parts[idx]
                    BottomNumberKeyView(
                        config: config,
                        isActive: false,
                        theme: state.theme,
                        cornerRadius: state.keyCornerRadius
                    )
                    .frame(height: height)
                }

                // Remaining space
                SpaceBarView(isActive: false, theme: state.theme, cornerRadius: state.keyCornerRadius)
                    .frame(height: height)
                    .background(
                        GeometryReader { geo in
                            let frame = geo.frame(in: .named("keyboard"))
                            Color.clear.onAppear {
                                spaceBarRegion = frame
                                gestureEngine.updateSpaceBarRegion(spaceBarRegion)
                            }
                            .onChange(of: frame) { newFrame in
                                spaceBarRegion = newFrame
                                gestureEngine.updateSpaceBarRegion(spaceBarRegion)
                            }
                        }
                    )
            }
            .frame(width: width)
        }
    }

    // MARK: - Enter Key

    @ViewBuilder
    private func enterKey(width: CGFloat, height: CGFloat) -> some View {
        let pos = GridPosition(row: 3, col: state.commandBarOnRight ? 3 : -1)

        CommandKeyView(
            config: KeyConfig(tap: "", specialAction: .enter, displayLabel: "return"),
            isActive: state.activeKeyPosition == pos,
            theme: state.theme,
            cornerRadius: state.keyCornerRadius
        )
        .frame(width: width, height: height)
        .background(
            GeometryReader { geo in
                let frame = geo.frame(in: .named("keyboard"))
                Color.clear.onAppear {
                    keyRegions[pos] = frame
                    gestureEngine.updateKeyRegions(keyRegions)
                }
                .onChange(of: frame) { newFrame in
                    keyRegions[pos] = newFrame
                    gestureEngine.updateKeyRegions(keyRegions)
                }
            }
        )
    }

    // MARK: - Overlays

    @ViewBuilder
    private func overlaysForKey(at pos: GridPosition, size: CGSize) -> some View {
        ZStack {
            // Shift indicator on key (1,2)
            if pos.row == 1 && pos.col == 2 {
                ShiftIndicatorView(
                    isShifted: state.isShifted,
                    isCapsLocked: state.isCapsLocked,
                    theme: state.theme
                )
                .position(x: size.width * 0.5, y: size.height * 0.12)
            }

            // Tab indicator on key (2,0)
            if pos.row == 2 && pos.col == 0 {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 10))
                    .foregroundColor(state.theme.tapColor)
                    .position(x: size.width * 0.85, y: size.height * 0.88)
            }

            // Clipboard indicator on key (0,0)
            if pos.row == 0 && pos.col == 0 {
                Text("C")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(state.theme.tapColor)
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(state.theme.tapColor.opacity(0.3))
                    )
                    .position(x: size.width * 0.1, y: size.height * 0.12)
            }

            // URL shortcut on h key.
            if pos == KeyboardLayoutData.dotComPosition && state.currentLayer == .letters && state.isURLField && state.showCenterLabels {
                Text(".com")
                    .font(.system(size: min(size.width, size.height) * 0.16, weight: .medium, design: .rounded))
                    .foregroundColor(state.theme.swipeColor)
                    .position(x: size.width * 0.5, y: size.height * 0.88)
            }

            // Punctuation on bottom keys (comma, period, colon, semicolon)
            // These are already in the swipe maps, handled by KeyView
        }
    }

    // MARK: - Active Key Tracking

    private func updateActiveKey(at point: CGPoint) {
        for (pos, rect) in keyRegions {
            if rect.contains(point) {
                state.activeKeyPosition = pos
                return
            }
        }
        if spaceBarRegion.contains(point) {
            state.activeKeyPosition = GridPosition(row: 3, col: 0)
        }
    }

    // MARK: - Gesture Trail

    private func resetGestureTrail(at point: CGPoint) {
        state.gestureTrailPoints = state.showGestureTrail ? [point] : []
    }

    private func appendGestureTrailPoint(_ point: CGPoint, force: Bool = false) {
        guard state.showGestureTrail else {
            state.gestureTrailPoints = []
            return
        }

        guard let lastPoint = state.gestureTrailPoints.last else {
            state.gestureTrailPoints = [point]
            return
        }

        guard force || distance(point, lastPoint) >= minTrailPointDistance else { return }

        state.gestureTrailPoints.append(point)
        if state.gestureTrailPoints.count > maxTrailDisplayPoints {
            state.gestureTrailPoints.removeFirst(state.gestureTrailPoints.count - maxTrailDisplayPoints)
        }
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Gesture Result Handling

    private func handleGestureResult(_ result: GestureResult) {
        switch result {
        case .tap(let pos):
            handleTap(at: pos)

        case .swipe(let pos, let dir):
            handleSwipe(from: pos, direction: dir, uppercase: false)

        case .swipeBack(let pos, let dir):
            handleSwipe(from: pos, direction: dir, uppercase: true)

        case .circle(let pos):
            handleCircle(at: pos)

        case .specialSwipe(let special):
            handleSpecialSwipe(special)

        case .none:
            break
        }
    }

    private func handleTap(at pos: GridPosition) {
        // Spacebar
        if pos == GridPosition(row: 3, col: 0) {
            onCharacter(" ")
            return
        }

        // Command bar keys
        if pos.col == 3 || pos.col == -1 {
            if pos.row == 3 {
                onEnter()
                return
            }
            handleCommandTap(row: pos.row)
            return
        }

        // Main grid
        let grid = state.currentGrid
        guard pos.row >= 0 && pos.row < grid.count,
              pos.col >= 0 && pos.col < grid[pos.row].count else { return }

        let config = grid[pos.row][pos.col]

        if let action = config.specialAction {
            handleSpecialAction(action)
            return
        }

        let char = state.applyCase(config.tap)
        if !char.isEmpty {
            onCharacter(char)
            state.afterCharacterInserted()
        }
    }

    private func handleSwipe(from pos: GridPosition, direction: SwipeDirection, uppercase: Bool) {
        if handleCommandSwipe(from: pos, isBackAndForth: uppercase) {
            return
        }

        let grid = state.currentGrid
        guard pos.row >= 0 && pos.row < grid.count,
              pos.col >= 0 && pos.col < grid[pos.row].count else { return }

        let config = grid[pos.row][pos.col]

        // Check for special overlays first
        if pos.row == 1 && pos.col == 2 && direction == .top {
            // Shift on 'r' key
            state.toggleShift()
            return
        }
        if pos.row == 2 && pos.col == 0 && direction == .bottomRight {
            // Tab
            onCharacter("\t")
            return
        }
        if state.currentLayer == .letters && state.isURLField && pos == KeyboardLayoutData.dotComPosition && direction == .bottom {
            onCharacter(".com")
            state.afterCharacterInserted()
            return
        }

        if let char = config.swipes[direction] ?? hiddenSymbolSwipe(from: pos, direction: direction) {
            let output: String
            if uppercase {
                output = char.uppercased()
            } else {
                output = state.applyCase(char)
            }
            onCharacter(output)
            state.afterCharacterInserted()
        }
    }

    private func hiddenSymbolSwipe(from pos: GridPosition, direction: SwipeDirection) -> String? {
        guard state.currentLayer == .letters, !state.isSymbolOverlayActive else { return nil }
        guard pos.row >= 0 && pos.row < KeyboardLayoutData.symbolOverlayGrid.count,
              pos.col >= 0 && pos.col < KeyboardLayoutData.symbolOverlayGrid[pos.row].count else {
            return nil
        }

        return KeyboardLayoutData.symbolOverlayGrid[pos.row][pos.col].swipes[direction]
    }

    private func handleCommandSwipe(from pos: GridPosition, isBackAndForth: Bool) -> Bool {
        guard pos.col == 3 || pos.col == -1 else { return false }
        let commands = state.currentCommandBar
        guard pos.row >= 0 && pos.row < commands.count else { return false }
        guard commands[pos.row].specialAction == .backspace else { return false }

        if isBackAndForth {
            onDeleteLine()
        } else {
            onDeleteWord()
        }
        return true
    }

    private func handleCircle(at pos: GridPosition) {
        let grid = state.currentGrid
        guard pos.row >= 0 && pos.row < grid.count,
              pos.col >= 0 && pos.col < grid[pos.row].count else { return }

        let config = grid[pos.row][pos.col]
        let char = config.tap.uppercased()
        if !char.isEmpty {
            onCharacter(char)
            state.afterCharacterInserted()
        }
    }

    private func handleCommandTap(row: Int) {
        let commands = state.currentCommandBar
        guard row >= 0 && row < commands.count else { return }

        if let action = commands[row].specialAction {
            handleSpecialAction(action)
        }
    }

    private func handleSpecialAction(_ action: SpecialAction) {
        switch action {
        case .globe:
            onNextKeyboard?()
        case .toggleLayer:
            state.toggleLayer()
        case .backspace:
            onBackspace()
        case .enter:
            onEnter()
        case .space:
            onCharacter(" ")
        case .shift:
            state.toggleShift()
        case .tab:
            onCharacter("\t")
        case .clipboard:
            // Paste from clipboard
            if let content = UIPasteboard.general.string {
                onCharacter(content)
            }
        }
    }

    private func handleSpecialSwipe(_ special: GestureResult.SpecialSwipe) {
        switch special {
        case .spaceSwipeUp:
            state.toggleSymbolsOnly()
        case .spaceSwipeUpAndBack:
            state.toggleCenterLabels()
        case .globeSwipeLeft, .globeSwipeRight:
            state.toggleFullWidth()
        case .globeSwipeUp:
            state.increaseHeight()
        case .globeSwipeDown:
            state.decreaseHeight()
        case .globeCircle:
            state.toggleCommandBarSide()
        }
    }
}

private struct GestureTrailView: View {
    let points: [CGPoint]
    let theme: KeyboardTheme

    var body: some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            theme.tapColor.opacity(0.85),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
        .shadow(color: .black.opacity(0.2), radius: 2)
    }
}
