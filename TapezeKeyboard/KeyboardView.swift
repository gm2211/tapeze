import SwiftUI
import UIKit

// MARK: - Main Keyboard View

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    let onCharacter: (String) -> Void
    let onBackspace: () -> Void
    let onEnter: () -> Void
    let onNextKeyboard: (() -> Void)?

    @State private var keyRegions: [GridPosition: CGRect] = [:]
    @State private var spaceBarRegion: CGRect = .zero
    @State private var globeRegion: CGRect = .zero
    @State private var gestureEngine = GestureEngine()

    private let gridRows = 3
    private let gridCols = 3
    private let spacing: CGFloat = 2

    var body: some View {
        GeometryReader { outerGeo in
            let totalWidth = max(outerGeo.size.width, 1)
            let commandColWidth = max(totalWidth * 0.22, 1)
            let mainGridWidth: CGFloat = state.isFullWidth
                ? max(totalWidth - commandColWidth - spacing, 1)
                : max(totalWidth * 0.58, 1)

            let mainRowHeight = (state.keyboardHeight - spacing * 3) / 4
            let mainGridHeight = mainRowHeight * 3 + spacing * 2
            let bottomRowHeight = mainRowHeight

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    // Command bar on left (if configured)
                    if !state.commandBarOnRight {
                        commandBar(width: commandColWidth, totalHeight: mainGridHeight)
                    }

                    // Spacer for non-full-width mode (left side)
                    if !state.isFullWidth && !state.commandBarOnRight {
                        Spacer(minLength: 0)
                    }

                    // Main 3x3 grid
                    mainGrid(width: mainGridWidth, height: mainGridHeight, rowHeight: mainRowHeight)

                    // Spacer for non-full-width mode (right side)
                    if !state.isFullWidth && state.commandBarOnRight {
                        Spacer(minLength: 0)
                    }

                    // Command bar on right (if configured)
                    if state.commandBarOnRight {
                        commandBar(width: commandColWidth, totalHeight: mainGridHeight)
                    }
                }

                // Bottom row: spacebar plus return key.
                HStack(spacing: spacing) {
                    if !state.commandBarOnRight {
                        enterKey(width: commandColWidth, height: bottomRowHeight)
                    }

                    if !state.isFullWidth && !state.commandBarOnRight {
                        Spacer(minLength: 0)
                    }

                    bottomRow(width: mainGridWidth, height: bottomRowHeight)

                    if !state.isFullWidth && state.commandBarOnRight {
                        Spacer(minLength: 0)
                    }

                    if state.commandBarOnRight {
                        enterKey(width: commandColWidth, height: bottomRowHeight)
                    }
                }
            }
            .frame(height: state.keyboardHeight)
            .background(KeyboardTheme.keyboardBackground)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboard"))
                    .onChanged { value in
                        if !gestureEngine.hasActiveGesture {
                            gestureEngine.touchBegan(at: value.startLocation)
                        }
                        gestureEngine.touchMoved(to: value.location)
                        updateActiveKey(at: value.location)
                    }
                    .onEnded { value in
                        if !gestureEngine.hasActiveGesture {
                            gestureEngine.touchBegan(at: value.startLocation)
                        }
                        let result = gestureEngine.touchEnded(at: value.location)
                        handleGestureResult(result)
                        state.activeKeyPosition = nil
                        state.swipeDirection = nil
                    }
            )
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

    @ViewBuilder
    private func mainGrid(width: CGFloat, height: CGFloat, rowHeight: CGFloat) -> some View {
        let colWidth = max((width - spacing * CGFloat(gridCols - 1)) / CGFloat(gridCols), 1)
        let grid = state.currentGrid
        let isSymbolOverlay = state.currentLayer == .letters && state.isSymbolOverlayActive
        let showCenter = state.currentLayer != .symbolsOnly && state.showCenterLabels
        let showSwipes = state.currentLayer != .letters || state.showCenterLabels || isSymbolOverlay

        VStack(spacing: spacing) {
            ForEach(0..<gridRows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridCols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        let config = grid[row][col]
                        let isActive = state.activeKeyPosition == pos

                        CharacterKeyView(
                            config: config,
                            isActive: isActive,
                            showCenter: showCenter,
                            showSwipes: showSwipes,
                            isShifted: state.isShifted || state.isCapsLocked
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
                    isActive: state.activeKeyPosition == commandPos
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
            SpaceBarView(isActive: state.activeKeyPosition == GridPosition(row: 3, col: 0))
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
                        isActive: false
                    )
                    .frame(height: height)
                }

                // Remaining space
                SpaceBarView(isActive: false)
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
            isActive: state.activeKeyPosition == pos
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
                    isCapsLocked: state.isCapsLocked
                )
                .position(x: size.width * 0.5, y: size.height * 0.12)
            }

            // Tab indicator on key (2,0)
            if pos.row == 2 && pos.col == 0 {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 10))
                    .foregroundColor(KeyboardTheme.tapColor)
                    .position(x: size.width * 0.85, y: size.height * 0.88)
            }

            // Clipboard indicator on key (0,0)
            if pos.row == 0 && pos.col == 0 {
                Text("C")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KeyboardTheme.tapColor)
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KeyboardTheme.tapColor.opacity(0.3))
                    )
                    .position(x: size.width * 0.1, y: size.height * 0.12)
            }

            // ".com" on key (1,0)
            if pos.row == 1 && pos.col == 0 && state.currentLayer == .letters && !state.isSymbolOverlayActive && state.showCenterLabels {
                Text(".com")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(KeyboardTheme.swipeColor)
                    .position(x: size.width * 0.35, y: size.height * 0.88)
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

        if let char = config.swipes[direction] {
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
