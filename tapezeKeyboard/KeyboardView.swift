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
    private let spacing: CGFloat = 1
    private let maxTrailDisplayPoints = 42
    private let minTrailPointDistance: CGFloat = 7

    var body: some View {
        GeometryReader { outerGeo in
            let totalWidth = max(outerGeo.size.width, 1)
            let totalHeight = max(outerGeo.size.height, 1)
            let keySide = max(
                min(
                    (totalWidth - spacing * CGFloat(gridCols - 1)) / CGFloat(gridCols),
                    (totalHeight - spacing * CGFloat(gridRows - 1)) / CGFloat(gridRows)
                ),
                1
            )
            let shouldDisableCompact = false
            let commandColWidth: CGFloat = 0
            let mainGridWidth = keySide * CGFloat(gridCols) + spacing * CGFloat(gridCols - 1)
            let mainGridHeight = keySide * CGFloat(gridRows) + spacing * CGFloat(gridRows - 1)
            let bottomRowHeight: CGFloat = 0
            let layoutWidth = mainGridWidth
            let layoutOriginX = (totalWidth - layoutWidth) / 2
            let hitLayout = LatticeHitLayout(
                originX: layoutOriginX,
                layoutWidth: layoutWidth,
                mainGridWidth: mainGridWidth,
                mainGridHeight: mainGridHeight,
                commandColWidth: commandColWidth,
                keySide: keySide,
                rowHeight: keySide,
                bottomRowHeight: bottomRowHeight,
                commandBarOnRight: state.commandBarOnRight
            )

            latticeKeyboard(
                layoutWidth: layoutWidth,
                mainGridWidth: mainGridWidth,
                mainGridHeight: mainGridHeight,
                commandColWidth: commandColWidth,
                keySide: keySide,
                rowHeight: keySide,
                bottomRowHeight: bottomRowHeight
            )
            .frame(width: layoutWidth, height: totalHeight, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: totalHeight)
            .background(state.theme.keyboardBackground)
            .onAppear {
                if shouldDisableCompact {
                    state.isFullWidth = true
                }
                registerHitLayout(hitLayout)
            }
            .onChange(of: shouldDisableCompact) { disableCompact in
                if disableCompact {
                    state.isFullWidth = true
                }
            }
            .onChange(of: hitLayout) { newLayout in
                registerHitLayout(newLayout)
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

    @ViewBuilder
    private func latticeKeyboard(
        layoutWidth: CGFloat,
        mainGridWidth: CGFloat,
        mainGridHeight: CGFloat,
        commandColWidth: CGFloat,
        keySide: CGFloat,
        rowHeight: CGFloat,
        bottomRowHeight: CGFloat
    ) -> some View {
        let mainX = state.commandBarOnRight ? 0 : commandColWidth
        let diamondSide = keySide * 0.54
        let commandBarCol = state.commandBarOnRight ? 3 : -1

        ZStack(alignment: .topLeading) {
            mainGrid(width: mainGridWidth, height: mainGridHeight, rowHeight: rowHeight)
                .frame(width: mainGridWidth, height: mainGridHeight)
                .position(x: mainX + mainGridWidth / 2, y: mainGridHeight / 2)

            internalCommandDiamond(
                config: KeyConfig(tap: "", specialAction: .globe, displayLabel: "globe"),
                position: GridPosition(row: 0, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide + spacing / 2, y: rowHeight + spacing / 2),
                updatesGlobe: true
            )

            internalCommandDiamond(
                config: KeyConfig(tap: state.currentLayer == .letters ? "123" : "abc", specialAction: .toggleLayer, displayLabel: state.currentLayer == .letters ? "123" : "abc"),
                position: GridPosition(row: 1, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide * 2 + spacing * 1.5, y: rowHeight + spacing / 2),
                updatesGlobe: false
            )

            internalCommandDiamond(
                config: KeyConfig(tap: "", specialAction: .enter, displayLabel: "return"),
                position: GridPosition(row: 3, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide * 2 + spacing * 1.5, y: rowHeight * 2 + spacing * 1.5),
                updatesGlobe: false,
                updatesResize: true
            )

            internalCommandDiamond(
                config: KeyConfig(tap: "", specialAction: .shift, displayLabel: "shift"),
                position: GridPosition(row: 4, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide + spacing / 2, y: rowHeight * 2 + spacing * 1.5),
                updatesGlobe: false
            )
        }
        .frame(width: layoutWidth, height: mainGridHeight, alignment: .topLeading)
    }

    private func registerHitLayout(_ layout: LatticeHitLayout) {
        let commandCol = layout.commandBarOnRight ? 3 : -1
        let mainX = layout.originX
        let diamondSide = layout.keySide * 0.54
        let diamondHalf = diamondSide / 2

        var regions: [GridPosition: CGRect] = [:]

        for row in 0..<gridRows {
            for col in 0..<gridCols {
                regions[GridPosition(row: row, col: col)] = CGRect(
                    x: mainX + CGFloat(col) * (layout.keySide + spacing),
                    y: CGFloat(row) * (layout.rowHeight + spacing),
                    width: layout.keySide,
                    height: layout.rowHeight
                )
            }
        }

        let globeCenter = CGPoint(
            x: mainX + layout.keySide + spacing / 2,
            y: layout.rowHeight + spacing / 2
        )
        let layerCenter = CGPoint(
            x: mainX + layout.keySide * 2 + spacing * 1.5,
            y: layout.rowHeight + spacing / 2
        )
        let shiftCenter = CGPoint(
            x: mainX + layout.keySide + spacing / 2,
            y: layout.rowHeight * 2 + spacing * 1.5
        )
        let enterCenter = CGPoint(
            x: mainX + layout.keySide * 2 + spacing * 1.5,
            y: layout.rowHeight * 2 + spacing * 1.5
        )

        regions[GridPosition(row: 0, col: commandCol)] = CGRect(
            x: globeCenter.x - diamondHalf,
            y: globeCenter.y - diamondHalf,
            width: diamondSide,
            height: diamondSide
        )
        regions[GridPosition(row: 1, col: commandCol)] = CGRect(
            x: layerCenter.x - diamondHalf,
            y: layerCenter.y - diamondHalf,
            width: diamondSide,
            height: diamondSide
        )
        regions[GridPosition(row: 4, col: commandCol)] = CGRect(
            x: shiftCenter.x - diamondHalf,
            y: shiftCenter.y - diamondHalf,
            width: diamondSide,
            height: diamondSide
        )
        regions[GridPosition(row: 3, col: commandCol)] = CGRect(
            x: enterCenter.x - diamondHalf,
            y: enterCenter.y - diamondHalf,
            width: diamondSide,
            height: diamondSide
        )
        keyRegions = regions
        spaceBarRegion = .zero
        globeRegion = regions[GridPosition(row: 0, col: commandCol)] ?? .zero
        gestureEngine.updateKeyRegions(regions)
        gestureEngine.updateSpaceBarRegion(.zero)
        gestureEngine.updateGlobeRegion(globeRegion)
        gestureEngine.updateResizeRegion(regions[GridPosition(row: 3, col: commandCol)] ?? .zero)
    }

    private func compactEmptyColumn(width: CGFloat) -> some View {
        state.theme.emptyColumnBackground
            .frame(width: width)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func internalCommandDiamond(
        config: KeyConfig,
        position: GridPosition,
        size: CGFloat,
        center: CGPoint,
        updatesGlobe: Bool,
        updatesResize: Bool = false
    ) -> some View {
        DiamondCommandKeyView(
            config: config,
            isActive: state.activeKeyPosition == position,
            isShifted: config.specialAction == .shift ? state.isShifted : false,
            isCapsLocked: config.specialAction == .shift ? state.isCapsLocked : false,
            theme: state.theme,
            cornerRadius: state.keyCornerRadius
        )
        .frame(width: size, height: size)
        .position(center)
    }

    private func commandHitRegion(row: Int, col: Int) -> some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("keyboard"))
            Color.clear.onAppear {
                keyRegions[GridPosition(row: row, col: col)] = frame
                gestureEngine.updateKeyRegions(keyRegions)
            }
            .onChange(of: frame) { newFrame in
                keyRegions[GridPosition(row: row, col: col)] = newFrame
                gestureEngine.updateKeyRegions(keyRegions)
            }
        }
    }

    private func cutCornersForKey(row: Int, col: Int) -> Set<KeyCorner> {
        var corners: Set<KeyCorner> = []
        if row > 0 && col > 0 { corners.insert(.topLeft) }
        if row > 0 && col < gridCols - 1 { corners.insert(.topRight) }
        if row < gridRows - 1 && col < gridCols - 1 { corners.insert(.bottomRight) }
        if row < gridRows - 1 && col > 0 { corners.insert(.bottomLeft) }
        return corners
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
                        let visualConfig = isSymbolOverlay ? KeyboardLayoutData.activeSymbolOverlayGrid()[row][col] : config
                        let letterSwipeLabels = isSymbolOverlay ? KeyboardLayoutData.activeLetterGrid()[row][col].swipes : nil
                        let isActive = state.activeKeyPosition == pos

                        CharacterKeyView(
                            config: visualConfig,
                            letterSwipeLabels: letterSwipeLabels,
                            isActive: isActive,
                            showCenter: showCenter,
                            showSwipes: showSwipes,
                            showSymbolOverlay: isSymbolOverlay,
                            isShifted: state.isShifted || state.isCapsLocked,
                            theme: state.theme,
                            cornerRadius: state.keyCornerRadius,
                            cutCorners: cutCornersForKey(row: row, col: col)
                        )
                        .frame(width: colWidth, height: rowHeight)
                        .overlay(
                            overlaysForKey(at: pos, size: CGSize(width: colWidth, height: rowHeight))
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
        let side: CommandVisualSide = state.commandBarOnRight ? .right : .left

        ZStack {
            if let backspaceIndex = commands.firstIndex(where: { $0.specialAction == .backspace }) {
                let backspacePos = GridPosition(row: backspaceIndex, col: state.commandBarOnRight ? 3 : -1)

                DeleteColumnKeyView(
                    isActive: state.activeKeyPosition == backspacePos,
                    side: side,
                    theme: state.theme,
                    cornerRadius: state.keyCornerRadius
                )
                .frame(width: width * 0.96, height: totalHeight)

                Image(systemName: "delete.backward.fill")
                    .font(.system(size: rowHeight * 0.26))
                    .foregroundColor(state.theme.specialTextColor)
                    .commandLabelDepth(for: state.theme)
                    .position(
                        x: state.commandBarOnRight ? width * 0.62 : width * 0.38,
                        y: rowCenter(for: backspaceIndex, rowHeight: rowHeight)
                    )
            }

            ForEach(0..<commands.count, id: \.self) { idx in
                let config = commands[idx]
                if config.specialAction != .backspace {
                    DiamondCommandKeyView(
                        config: config,
                        isActive: state.activeKeyPosition == GridPosition(row: idx, col: state.commandBarOnRight ? 3 : -1),
                        theme: state.theme,
                        cornerRadius: state.keyCornerRadius
                    )
                    .frame(width: rowHeight * 0.72, height: rowHeight * 0.72)
                    .position(
                        x: state.commandBarOnRight ? width * 0.08 : width * 0.92,
                        y: rowCenter(for: idx, rowHeight: rowHeight)
                    )
                }
            }

            ForEach(0..<commands.count, id: \.self) { idx in
                let config = commands[idx]
                let commandPos = GridPosition(row: idx, col: state.commandBarOnRight ? 3 : -1)

                Color.clear
                    .frame(width: width, height: rowHeight)
                    .position(x: width / 2, y: rowCenter(for: idx, rowHeight: rowHeight))
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
        .frame(width: width, height: totalHeight)
    }

    private func rowCenter(for index: Int, rowHeight: CGFloat) -> CGFloat {
        CGFloat(index) * (rowHeight + spacing) + rowHeight / 2
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

        ZStack {
            DiamondCommandKeyView(
                config: KeyConfig(tap: "", specialAction: .enter, displayLabel: "return"),
                isActive: state.activeKeyPosition == pos,
                theme: state.theme,
                cornerRadius: state.keyCornerRadius
            )
            .frame(width: height * 0.72, height: height * 0.72)
            .position(x: state.commandBarOnRight ? width * 0.08 : width * 0.92, y: height / 2)

            Color.clear
                .background(
                    GeometryReader { geo in
                        let frame = geo.frame(in: .named("keyboard"))
                        Color.clear.onAppear {
                            keyRegions[pos] = frame
                            gestureEngine.updateKeyRegions(keyRegions)
                            gestureEngine.updateResizeRegion(frame)
                        }
                        .onChange(of: frame) { newFrame in
                            keyRegions[pos] = newFrame
                            gestureEngine.updateKeyRegions(keyRegions)
                            gestureEngine.updateResizeRegion(newFrame)
                        }
                    }
                )
        }
        .frame(width: width, height: height)
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
                    .position(x: size.width * 0.80, y: size.height * 0.82)
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
                    .position(x: size.width * 0.14, y: size.height * 0.15)
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
        if let pos = gestureEngine.keyPosition(at: point) {
            state.activeKeyPosition = pos
            return
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
        guard state.currentLayer == .letters else { return nil }
        let symbolOverlayGrid = KeyboardLayoutData.activeSymbolOverlayGrid()
        guard pos.row >= 0 && pos.row < symbolOverlayGrid.count,
              pos.col >= 0 && pos.col < symbolOverlayGrid[pos.row].count else {
            return nil
        }

        return symbolOverlayGrid[pos.row][pos.col].swipes[direction]
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
        switch row {
        case 0:
            handleSpecialAction(.globe)
        case 1:
            handleSpecialAction(.toggleLayer)
        case 2:
            handleSpecialAction(.backspace)
        case 3:
            handleSpecialAction(.enter)
        case 4:
            handleSpecialAction(.shift)
        default:
            break
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
        case .keyboardSpace:
            onCharacter(" ")
        case .keyboardBackspace:
            onBackspace()
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

private struct LatticeHitLayout: Equatable {
    let originX: CGFloat
    let layoutWidth: CGFloat
    let mainGridWidth: CGFloat
    let mainGridHeight: CGFloat
    let commandColWidth: CGFloat
    let keySide: CGFloat
    let rowHeight: CGFloat
    let bottomRowHeight: CGFloat
    let commandBarOnRight: Bool
}
