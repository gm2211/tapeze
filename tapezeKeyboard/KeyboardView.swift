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
    @State private var activeBridge: ActiveBridge = .none
    @State private var backspacePath: [CGPoint] = []
    @State private var currentKeySide: CGFloat = 1

    private let gridRows = 3
    private let gridCols = 3
    private let spacing: CGFloat = 1
    private let maxTrailDisplayPoints = 42
    private let minTrailPointDistance: CGFloat = 7

    var body: some View {
        GeometryReader { outerGeo in
            let totalWidth = max(outerGeo.size.width, 1)
            let totalHeight = max(outerGeo.size.height, 1)

            // Anchor the grid against the outer edge and let the delete rail
            // absorb the remaining width. This removes the unused side gutters.
            let targetBackspaceRailWidth = max(totalWidth * 0.24, 76)
            let usableWidth = max(totalWidth - targetBackspaceRailWidth - spacing, 1)

            // Compute strip height based on a preliminary keySide estimate from the full height.
            let prelimKeySide = max(
                min(
                    (usableWidth - spacing * CGFloat(gridCols - 1)) / CGFloat(gridCols),
                    (totalHeight - spacing * CGFloat(gridRows - 1)) / CGFloat(gridRows)
                ),
                1
            )
            let prelimStripHeight = prelimKeySide * 0.32

            // Inner height available for the main 3×3 grid (total minus both strips).
            let innerHeight = max(totalHeight - 2 * prelimStripHeight, 1)
            let keySide = max(
                min(
                    (usableWidth - spacing * CGFloat(gridCols - 1)) / CGFloat(gridCols),
                    (innerHeight - spacing * CGFloat(gridRows - 1)) / CGFloat(gridRows)
                ),
                1
            )

            let shouldDisableCompact = false
            let commandColWidth: CGFloat = 0
            let mainGridWidth = keySide * CGFloat(gridCols) + spacing * CGFloat(gridCols - 1)
            let mainGridHeight = keySide * CGFloat(gridRows) + spacing * CGFloat(gridRows - 1)
            let backspaceRailWidth = max(totalWidth - mainGridWidth - spacing, 1)

            // Absorb slack into strips so grid fills exactly innerHeight with no gap.
            let stripHeight = max((totalHeight - mainGridHeight) / 2, prelimKeySide * 0.20)
            let armWidth = keySide * 0.40
            let bottomRowHeight: CGFloat = 0
            let layoutOriginX = state.commandBarOnRight ? 0 : backspaceRailWidth + spacing
            let hitLayout = LatticeHitLayout(
                originX: layoutOriginX,
                originY: stripHeight,
                layoutWidth: mainGridWidth,
                mainGridWidth: mainGridWidth,
                mainGridHeight: mainGridHeight,
                commandColWidth: commandColWidth,
                keySide: keySide,
                rowHeight: keySide,
                bottomRowHeight: bottomRowHeight,
                commandBarOnRight: state.commandBarOnRight
            )

            ZStack(alignment: .topLeading) {
                bridgeBackground(
                    totalWidth: totalWidth,
                    totalHeight: totalHeight,
                    stripHeight: stripHeight,
                    mainGridHeight: mainGridHeight,
                    rowHeight: keySide,
                    layoutOriginX: layoutOriginX,
                    mainGridWidth: mainGridWidth,
                    backspaceRailWidth: backspaceRailWidth
                )

                latticeKeyboard(
                    layoutWidth: mainGridWidth,
                    mainGridWidth: mainGridWidth,
                    mainGridHeight: mainGridHeight,
                    commandColWidth: commandColWidth,
                    keySide: keySide,
                    rowHeight: keySide,
                    bottomRowHeight: bottomRowHeight,
                    armWidth: armWidth
                )
                .frame(width: mainGridWidth, height: mainGridHeight)
                .position(x: layoutOriginX + mainGridWidth / 2, y: stripHeight + mainGridHeight / 2)
            }
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
                        // Determine bridge membership once, on gesture START.
                        if !gestureEngine.hasActiveGesture {
                            activeBridge = bridgeAt(
                                value.startLocation,
                                totalWidth: totalWidth,
                                totalHeight: totalHeight,
                                stripHeight: stripHeight,
                                armWidth: armWidth,
                                rowHeight: keySide,
                                layoutOriginX: layoutOriginX,
                                mainGridWidth: mainGridWidth,
                                backspaceRailWidth: backspaceRailWidth
                            )
                        }

                        if activeBridge != .none {
                            // Bridge touches: feed bottom-bridge into gestureEngine so space-swipe-up works.
                            if activeBridge == .space {
                                if !gestureEngine.hasActiveGesture {
                                    gestureEngine.touchBegan(at: value.startLocation)
                                }
                                gestureEngine.touchMoved(to: value.location)
                            } else if activeBridge == .backspace {
                                // Track top-bridge path so we can recognize horizontal swipe → delete-word.
                                if backspacePath.isEmpty {
                                    backspacePath = [value.startLocation]
                                }
                                backspacePath.append(value.location)
                            }
                            return
                        }

                        // Key touch path
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
                        defer {
                            activeBridge = .none
                            backspacePath = []
                        }

                        if activeBridge == .backspace {
                            backspacePath.append(value.location)
                            let action = analyzeBackspacePath(backspacePath, keySide: keySide)
                            switch action {
                            case .single:
                                onBackspace()
                            case .word:
                                onDeleteWord()
                            case .line:
                                onDeleteLine()
                            case .cancel:
                                break
                            }
                            state.gestureTrailPoints = []
                            state.activeKeyPosition = nil
                            return
                        }

                        if activeBridge == .space {
                            // Let gestureEngine evaluate first — it may recognize a space-swipe-up gesture.
                            if !gestureEngine.hasActiveGesture {
                                gestureEngine.touchBegan(at: value.startLocation)
                            }
                            let result = gestureEngine.touchEnded(at: value.location)
                            switch result {
                            case .specialSwipe(let special) where special == .spaceSwipeUp || special == .spaceSwipeUpAndBack:
                                handleGestureResult(result)
                            default:
                                // Plain tap on bottom bridge: space in letters layer, "0" in number layers.
                                if state.currentLayer == .letters {
                                    onCharacter(" ")
                                } else {
                                    onCharacter("0")
                                }
                            }
                            state.gestureTrailPoints = []
                            state.activeKeyPosition = nil
                            state.swipeDirection = nil
                            return
                        }

                        // Key touch path — activeBridge == .none
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
        bottomRowHeight: CGFloat,
        armWidth: CGFloat = 0
    ) -> some View {
        let mainX = state.commandBarOnRight ? 0 : commandColWidth
        let diamondSide = keySide * 0.54
        let commandBarCol = state.commandBarOnRight ? 3 : -1

        ZStack(alignment: .topLeading) {
            mainGrid(width: mainGridWidth, height: mainGridHeight, rowHeight: rowHeight, armWidth: armWidth)
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

    // MARK: - Bridge Views

    private func bridgeBackground(
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        stripHeight: CGFloat,
        mainGridHeight: CGFloat,
        rowHeight: CGFloat,
        layoutOriginX: CGFloat,
        mainGridWidth: CGFloat,
        backspaceRailWidth: CGFloat
    ) -> some View {
        let gridBottom = stripHeight + mainGridHeight
        let spaceHeight = max(totalHeight - gridBottom, 0)
        let railX = state.commandBarOnRight
            ? layoutOriginX + mainGridWidth + spacing
            : 0
        let railWidth = max(backspaceRailWidth, 0)
        let railHeight = max(mainGridHeight, 0)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(spaceBridgeFill)
                .frame(width: totalWidth, height: spaceHeight)
                .position(x: totalWidth / 2, y: gridBottom + spaceHeight / 2)

            Rectangle()
                .fill(backspaceBridgeFill)
                .frame(width: railWidth, height: railHeight)
                .position(x: railX + railWidth / 2, y: stripHeight + railHeight / 2)

            Image(systemName: "delete.left")
                .font(.system(size: min(railWidth, rowHeight) * 0.42, weight: .medium))
                .foregroundColor(state.theme.specialTextColor)
                .frame(width: railWidth, height: railHeight)
                .position(x: railX + railWidth / 2, y: stripHeight + railHeight / 2)

            Group {
                if state.currentLayer == .letters {
                    Text("space")
                        .font(.system(size: stripHeight * 0.4, weight: .medium))
                } else {
                    Text("0")
                        .font(.system(size: stripHeight * 0.7, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(state.theme.specialTextColor)
            .frame(width: totalWidth, height: spaceHeight)
            .position(x: totalWidth / 2, y: gridBottom + spaceHeight / 2)
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
    }

    private func backspaceBridge(
        totalWidth: CGFloat,
        mainGridWidth: CGFloat,
        mainGridHeight: CGFloat,
        layoutOriginX: CGFloat,
        stripHeight: CGFloat,
        armWidth: CGFloat,
        rowHeight: CGFloat
    ) -> some View {
        let midY = stripHeight + mainGridHeight / 2
        let totalH = stripHeight + rowHeight
        return ExtendedBridgeShape(
            side: .top,
            totalWidth: totalWidth,
            mainGridWidth: mainGridWidth,
            layoutOriginX: layoutOriginX,
            stripHeight: stripHeight,
            armWidth: armWidth,
            rowHeight: rowHeight,
            midY: midY
        )
        .fill(bridgeFill)
        .overlay(
            Image(systemName: "delete.left")
                .font(.system(size: stripHeight * 0.6, weight: .medium))
                .foregroundColor(state.theme.specialTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: stripHeight)
            , alignment: .top
        )
        .frame(width: totalWidth, height: totalH)
    }

    private func spaceBridge(
        totalWidth: CGFloat,
        mainGridWidth: CGFloat,
        mainGridHeight: CGFloat,
        layoutOriginX: CGFloat,
        stripHeight: CGFloat,
        armWidth: CGFloat,
        rowHeight: CGFloat
    ) -> some View {
        let midY = stripHeight + mainGridHeight / 2
        let totalH = stripHeight + rowHeight
        return ExtendedBridgeShape(
            side: .bottom,
            totalWidth: totalWidth,
            mainGridWidth: mainGridWidth,
            layoutOriginX: layoutOriginX,
            stripHeight: stripHeight,
            armWidth: armWidth,
            rowHeight: rowHeight,
            midY: midY
        )
        .fill(bridgeFill)
        .overlay(
            Text("space")
                .font(.system(size: stripHeight * 0.4, weight: .medium))
                .foregroundColor(state.theme.specialTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: stripHeight)
            , alignment: .bottom
        )
        .frame(width: totalWidth, height: totalH)
    }

    private var bridgeFill: LinearGradient {
        LinearGradient(
            colors: [state.theme.commandGradientTop ?? state.theme.commandBackground,
                     state.theme.commandGradientBottom ?? state.theme.commandBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var backspaceBridgeFill: LinearGradient {
        LinearGradient(
            colors: [state.theme.commandGradientTop ?? state.theme.commandBackground,
                     state.theme.commandGradientBottom ?? state.theme.commandBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var spaceBridgeFill: LinearGradient {
        LinearGradient(
            colors: [state.theme.spaceGradientTop ?? state.theme.spaceBackground,
                     state.theme.spaceGradientBottom ?? state.theme.spaceBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Bridge Hit Testing

    private func bridgeAt(
        _ point: CGPoint,
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        stripHeight: CGFloat,
        armWidth: CGFloat,
        rowHeight: CGFloat,
        layoutOriginX: CGFloat,
        mainGridWidth: CGFloat,
        backspaceRailWidth: CGFloat
    ) -> ActiveBridge {
        let keySide = rowHeight
        let mainGridHeight = keySide * CGFloat(gridRows) + spacing * CGFloat(gridRows - 1)
        let gridBottom = stripHeight + mainGridHeight
        let railX = state.commandBarOnRight
            ? layoutOriginX + mainGridWidth + spacing
            : 0
        let railEndX = railX + backspaceRailWidth

        // Backspace rail mirrors to the side selected by the globe circle gesture.
        if point.x >= railX,
           point.x <= railEndX,
           point.y >= stripHeight,
           point.y < gridBottom {
            return .backspace
        }

        // Full-width bottom strip: y in [gridBottom, totalHeight]
        if point.y >= gridBottom {
            return .space
        }

        return .none
    }

    private func registerHitLayout(_ layout: LatticeHitLayout) {
        let commandCol = layout.commandBarOnRight ? 3 : -1
        let mainX = layout.originX
        let originY = layout.originY
        // Diamond hit rects are smaller than the visual to avoid overlapping letter cells.
        let diamondSide = layout.keySide * 0.40
        let diamondHalf = diamondSide / 2

        // Letter cell regions are now set via GeometryReader in mainGrid; only keep
        // the existing GeometryReader-sourced letter regions and write diamond regions.
        var regions: [GridPosition: CGRect] = keyRegions.filter { pos, _ in
            !isCommandPosition(pos: pos)
        }

        let globeCenter = CGPoint(
            x: mainX + layout.keySide + spacing / 2,
            y: originY + layout.rowHeight + spacing / 2
        )
        let layerCenter = CGPoint(
            x: mainX + layout.keySide * 2 + spacing * 1.5,
            y: originY + layout.rowHeight + spacing / 2
        )
        let shiftCenter = CGPoint(
            x: mainX + layout.keySide + spacing / 2,
            y: originY + layout.rowHeight * 2 + spacing * 1.5
        )
        let enterCenter = CGPoint(
            x: mainX + layout.keySide * 2 + spacing * 1.5,
            y: originY + layout.rowHeight * 2 + spacing * 1.5
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
        // Space bar region = bottom bridge strip (full width of grid, strip height at bottom)
        let bottomBridgeStripRect = CGRect(
            x: mainX,
            y: originY + layout.mainGridHeight,
            width: layout.mainGridWidth,
            height: originY  // originY == stripHeight
        )
        spaceBarRegion = bottomBridgeStripRect
        globeRegion = regions[GridPosition(row: 0, col: commandCol)] ?? .zero
        gestureEngine.updateKeyRegions(regions)
        gestureEngine.updateSpaceBarRegion(bottomBridgeStripRect)
        gestureEngine.updateGlobeRegion(globeRegion)
        gestureEngine.updateResizeRegion(regions[GridPosition(row: 3, col: commandCol)] ?? .zero)
    }

    private func isCommandPosition(pos: GridPosition) -> Bool {
        pos.col == 3 || pos.col == -1
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
    private func mainGrid(width: CGFloat, height: CGFloat, rowHeight: CGFloat, armWidth: CGFloat = 0) -> some View {
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
                        let labelShift: CGFloat = 0

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
                            cutCorners: cutCornersForKey(row: row, col: col),
                            labelHorizontalShift: labelShift
                        )
                        .frame(width: colWidth, height: rowHeight)
                        .background(
                            GeometryReader { geo in
                                let frame = geo.frame(in: .named("keyboard"))
                                Color.clear
                                    .onAppear {
                                        keyRegions[pos] = frame
                                        gestureEngine.updateKeyRegions(keyRegions)
                                    }
                                    .onChange(of: frame) { newFrame in
                                        keyRegions[pos] = newFrame
                                        gestureEngine.updateKeyRegions(keyRegions)
                                    }
                            }
                        )
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

    // MARK: - Backspace Bridge Gesture

    private enum BackspaceAction {
        case single
        case word
        case line
        case cancel
    }

    private func analyzeBackspacePath(_ path: [CGPoint], keySide: CGFloat) -> BackspaceAction {
        guard let start = path.first, let end = path.last else { return .cancel }
        let total = distance(end, start)

        if path.count < 3 || total < keySide * 0.18 {
            return .single
        }

        var maxLeft: CGFloat = 0
        var maxRight: CGFloat = 0
        var maxVertical: CGFloat = 0
        for point in path {
            let dx = point.x - start.x
            let dy = point.y - start.y
            maxLeft = max(maxLeft, -dx)
            maxRight = max(maxRight, dx)
            maxVertical = max(maxVertical, abs(dy))
        }

        let horizontalExcursion = max(maxLeft, maxRight)
        let returnedNearStart = total <= max(keySide * 0.35, 24)
        let backAndForthThreshold = keySide * 0.45

        // Both directions traversed and finger ended near start → delete entire line.
        if returnedNearStart,
           maxLeft >= backAndForthThreshold,
           maxRight >= backAndForthThreshold {
            return .line
        }

        // Cancel-by-large-vertical-slide.
        if maxVertical > horizontalExcursion * 1.3, maxVertical > keySide * 0.7 {
            return .cancel
        }

        // Horizontal swipe → delete word.
        if horizontalExcursion >= keySide * 0.5,
           horizontalExcursion > maxVertical * 1.1 {
            return .word
        }

        // Modest drag → still a single backspace.
        return .single
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
            state.toggleLayer()
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
    let originY: CGFloat
    let layoutWidth: CGFloat
    let mainGridWidth: CGFloat
    let mainGridHeight: CGFloat
    let commandColWidth: CGFloat
    let keySide: CGFloat
    let rowHeight: CGFloat
    let bottomRowHeight: CGFloat
    let commandBarOnRight: Bool
}

enum ActiveBridge: Equatable {
    case none, backspace, space
}

/// Extended bridge shape: covers the full keyboard width.
/// Top bridge (inverted U extended): full-width top strip + left/right margin panels reaching down to midY,
///   plus inner arm cut-in at the grid boundary.
/// Bottom bridge (U extended): full-width bottom strip + left/right margin panels reaching up from midY,
///   plus inner arm cut-in at the grid boundary.
/// midY is expressed in the view's local coordinate space (y=0 at the shape's top-left origin).
struct ExtendedBridgeShape: Shape {
    enum Side { case top, bottom }
    let side: Side
    let totalWidth: CGFloat
    let mainGridWidth: CGFloat
    let layoutOriginX: CGFloat
    let stripHeight: CGFloat
    let armWidth: CGFloat
    let rowHeight: CGFloat
    let midY: CGFloat
    let corner: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        // The shape's frame is (totalWidth × (stripHeight + rowHeight)).
        // For .top  shape is positioned so y=0 is the top edge of the keyboard.
        // For .bottom shape is positioned so y=(stripHeight+rowHeight) is the bottom edge.
        //
        // Grid inner boundary in local coords:
        //   gridLeft  = layoutOriginX
        //   gridRight = layoutOriginX + mainGridWidth
        //
        // .top:  arm cut-in is at y=stripHeight.
        //        left margin panel: x in [0, gridLeft], y in [0, midY_local]
        //        right margin panel: x in [gridRight, totalWidth], y in [0, midY_local]
        //        midY_local = midY  (midY passed in = stripHeight + mainGridHeight/2 in keyboard coords,
        //                            which equals the same offset from the top of this view since the view
        //                            starts at y=0 of the keyboard)
        // .bottom: arm cut-in is at y=rowHeight (from the top of this view = gridBottom in keyboard coords).
        //          left/right margin panels from y=(rowHeight - (midY_local_offset)) to y=rowHeight
        //          midY_local = midY - (totalHeight - stripHeight - rowHeight)
        //          Actually easier: pass midY as keyboard-space; this view's y=0 maps to keyboard y=(gridBottom).
        //          So local y for midY = midY - (gridBottom), where gridBottom = stripHeight + mainGridHeight
        //          But we don't have mainGridHeight directly — however midY = stripHeight + mainGridHeight/2,
        //          and the bottom bridge view top is at keyboard y = stripHeight + mainGridHeight = 2*midY - stripHeight.
        //          local_midY = midY - (2*midY - stripHeight) = stripHeight - midY  [negative if midY > stripHeight]
        //          That's always <= 0, meaning midY is above this view — so the margin panels span the full arm height.
        //          Simpler: for .bottom just make the margin panels run the full arm height (rowHeight) since midY
        //          is always at or above the bottom bridge view's top edge.
        var p = Path()
        let gridLeft = layoutOriginX
        let gridRight = layoutOriginX + mainGridWidth

        switch side {
        case .top:
            // midY in local coords (view starts at keyboard y=0, so local == keyboard for this view)
            let panelBottom = midY  // left/right margin panels run from y=0 down to midY

            // Outer contour, clockwise from top-left:
            // Top-left → top-right (full width strip)
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: totalWidth, y: 0))

            // Right edge down to bottom of right margin panel
            p.addLine(to: CGPoint(x: totalWidth, y: panelBottom))

            // Right margin panel inner edge (left side of right margin, going up to the arm cut-in)
            p.addLine(to: CGPoint(x: gridRight, y: panelBottom))
            p.addLine(to: CGPoint(x: gridRight, y: stripHeight + rowHeight))
            // Arm inner-corner cut-in (right arm)
            p.addLine(to: CGPoint(x: gridRight - armWidth, y: stripHeight + rowHeight))
            p.addLine(to: CGPoint(x: gridRight - armWidth, y: stripHeight + corner))
            p.addQuadCurve(
                to: CGPoint(x: gridRight - armWidth - corner, y: stripHeight),
                control: CGPoint(x: gridRight - armWidth, y: stripHeight)
            )
            // Inner bottom of the strip, right portion → left portion
            p.addLine(to: CGPoint(x: gridLeft + armWidth + corner, y: stripHeight))
            // Arm inner-corner cut-in (left arm)
            p.addQuadCurve(
                to: CGPoint(x: gridLeft + armWidth, y: stripHeight + corner),
                control: CGPoint(x: gridLeft + armWidth, y: stripHeight)
            )
            p.addLine(to: CGPoint(x: gridLeft + armWidth, y: stripHeight + rowHeight))
            p.addLine(to: CGPoint(x: gridLeft, y: stripHeight + rowHeight))
            // Left margin panel inner edge (right side of left margin, going up from arm bottom to panelBottom)
            p.addLine(to: CGPoint(x: gridLeft, y: panelBottom))
            // Left edge back to top-left
            p.addLine(to: CGPoint(x: 0, y: panelBottom))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.closeSubpath()

        case .bottom:
            // For the bottom bridge, this view's local y=0 corresponds to keyboard y=gridBottom,
            // and local y=(rowHeight+stripHeight) is the keyboard bottom edge.
            // midY (keyboard space) is above this view's top, so margin panels always span the full arm height.
            // We draw the full left/right margin panels (full rowHeight tall) as side extensions.

            // Outer contour, clockwise from top-left:
            // Left outer edge top-left corner of left margin panel
            p.move(to: CGPoint(x: 0, y: 0))
            // Left margin panel top-right corner → arm inner corner
            p.addLine(to: CGPoint(x: gridLeft, y: 0))
            p.addLine(to: CGPoint(x: gridLeft, y: rowHeight))
            p.addLine(to: CGPoint(x: gridLeft + armWidth, y: rowHeight))
            // Left arm inner corner (bottom of arm meets grid)
            p.addLine(to: CGPoint(x: gridLeft + armWidth, y: corner))
            p.addQuadCurve(
                to: CGPoint(x: gridLeft + armWidth + corner, y: 0),
                control: CGPoint(x: gridLeft + armWidth, y: 0)
            )
            // Inner top of the strip, left portion → right portion (below grid)
            p.addLine(to: CGPoint(x: gridRight - armWidth - corner, y: 0))
            // Right arm inner corner
            p.addQuadCurve(
                to: CGPoint(x: gridRight - armWidth, y: corner),
                control: CGPoint(x: gridRight - armWidth, y: 0)
            )
            p.addLine(to: CGPoint(x: gridRight - armWidth, y: rowHeight))
            p.addLine(to: CGPoint(x: gridRight, y: rowHeight))
            // Right margin panel inner edge going back up
            p.addLine(to: CGPoint(x: gridRight, y: 0))
            // Right outer edge top → bottom
            p.addLine(to: CGPoint(x: totalWidth, y: 0))
            p.addLine(to: CGPoint(x: totalWidth, y: rowHeight + stripHeight))
            // Bottom edge right → left
            p.addLine(to: CGPoint(x: 0, y: rowHeight + stripHeight))
            p.closeSubpath()
        }
        return p
    }
}
