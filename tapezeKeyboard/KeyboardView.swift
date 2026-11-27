import SwiftUI
import UIKit
import Combine

// MARK: - Main Keyboard View

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    let onCharacter: (String) -> Void
    let onBackspace: () -> Void
    let onDeleteWord: () -> Void
    let onDeleteLine: () -> Void
    let onEnter: () -> Void
    let onMoveCursor: (Int) -> Void
    /// Moves the cursor by whole words: negative is left, positive right.
    var onMoveCursorByWord: (Int) -> Void = { _ in }
    let onNextKeyboard: (() -> Void)?
    /// Undo, redo and copy from the tool column.
    var onToolAction: (ToolColumnAction) -> Void = { _ in }
    var onDictation: (() -> Void)? = nil

    @State private var keyRegions: [GridPosition: CGRect] = [:]
    @State private var spaceBarRegion: CGRect = .zero
    @State private var spaceBarGutterRegion: CGRect = .zero
    @State private var globeRegion: CGRect = .zero
    @State private var gestureEngine = GestureEngine()
    /// The layout the engine's hit regions were last built from. A reference
    /// so checking it on every touch never re-renders the keyboard.
    @State private var registeredHitLayout = RegisteredHitLayout()
    @State private var activeBridge: ActiveBridge = .none
    @State private var backspacePath: [CGPoint] = []
    @State private var backspaceScrub = BackspaceScrubTracker()
    @State private var spaceCursor = SpaceCursorTracker()
    @State private var currentKeySide: CGFloat = 1
    @State private var longPressTask: DispatchWorkItem?
    @State private var longPressTriggered = false
    /// The accent strip open under a held finger, if any.
    @State private var holdPicker: HoldPicker?
    /// Where the finger last settled. The hold timer restarts whenever the
    /// finger moves away from it, so it only fires once the finger is still.
    @State private var holdAnchor: CGPoint = .zero
    /// How far the tool column's wheel is scrolled, in points.
    @State private var toolOffset: CGFloat = 0
    @State private var toolOffsetLoaded = false
    /// Wheel offset and finger height when the current column touch began.
    @State private var toolDragStart: (offset: CGFloat, y: CGFloat)?
    /// Recent finger heights on the column, for the release speed.
    @State private var toolSamples: [(y: CGFloat, time: TimeInterval)] = []
    @State private var toolDidScroll = false
    /// Row the finger is on, drawn pressed while it stays a tap.
    @State private var toolPressedIndex: Int?
    @State private var logicalGestureActive = false
    @State private var lastTrackedPoint: CGPoint?
    /// The finger driving the current logical gesture. Other fingers that are
    /// still down after being superseded are ignored until they lift.
    @State private var primaryTouch: ObjectIdentifier?
    /// Horizontal shift applied to each finger that landed on the split
    /// keyboard's mirror half, so it is read as the same spot on the primary
    /// half. Fixed at touchdown so a swipe keeps its direction and length.
    @State private var splitTouchOffsets: [ObjectIdentifier: CGFloat] = [:]
    /// Shift from hit-test space back to where the finger really is, for the
    /// finger that just landed. The trail stores real positions, so a trail
    /// already drawn on one half stays there when the next tap lands on the
    /// other half (shifting the whole trail view moved it across).
    @State private var pendingTrailOffsetX: CGFloat = 0
    /// The same shift for the gesture currently drawing its trail.
    @State private var activeTrailOffsetX: CGFloat = 0
    /// Whether the last layout pass drew two halves, for the globe toggle.
    @State private var isSplitShown = false

    private let gridRows = 3
    private let gridCols = 3
    /// MessagEase leaves 2pt between keys, including above the space row.
    private let spacing: CGFloat = 2
    private let maxTrailDisplayPoints = 42
    private let minTrailPointDistance: CGFloat = 7
    private let numberHoldDuration: TimeInterval = 0.6
    /// How long a finger must rest at the end of a swipe to open that
    /// letter's accents. Shorter than the touchdown hold: the finger has
    /// already committed to a letter, and a normal swipe lifts without a pause.
    private let swipeHoldDuration: TimeInterval = 0.45
    /// Movement that counts as the finger leaving where it settled.
    private let holdStillnessRadius: CGFloat = 10

    var body: some View {
        GeometryReader { outerGeo in
            let totalWidth = max(outerGeo.size.width, 1)
            let totalHeight = max(outerGeo.size.height, 1)

            let minimumControlExtent: CGFloat = 60
            /// Floor for very short keyboards so the bar stays a usable target.
            let minimumSpaceBarHeight: CGFloat = 56
            /// Space bar height as a multiple of one key row. MessagEase draws four equal
            /// 72pt rows, so the space row matches a key row.
            let spaceBarRowRatio: CGFloat = 1.0
            /// Keys and the command column share the width in four equal columns.
            /// Holding keys to MessagEase's 78:72 shape left 84pt empty on the
            /// left of a 402pt iPhone (122pt on a Pro Max), which reviewers read
            /// as wasted space. Keys now stretch to fill a phone's width; the cap
            /// only stops them turning into slabs on very wide screens, where
            /// the split keyboard is the better fit.
            let maxKeyAspectRatio: CGFloat = 1.6
            // Solve for the row height so that `gridRows` key rows plus a space bar
            // sized at `spaceBarRowRatio` key rows, plus the inter-row spacing
            // (including the gap above the space row), exactly fill the available height.
            let keyHeightByRowRatio = max(
                (totalHeight - spacing * CGFloat(gridRows)) / (CGFloat(gridRows) + spaceBarRowRatio),
                1
            )
            let keyHeightBySpaceFloor = max(
                (totalHeight - spacing * CGFloat(gridRows) - minimumSpaceBarHeight) / CGFloat(gridRows),
                1
            )
            let keyHeight = min(keyHeightByRowRatio, keyHeightBySpaceFloor)
            // Three key columns plus a command column of the same width.
            let maxKeyWidthByWidth = max(
                (totalWidth - spacing * CGFloat(gridCols)) / CGFloat(gridCols + 1),
                1
            )
            /// Each split half keeps MessagEase's 78:72 keys, so whether both
            /// halves fit is judged at that size, not at the stretched one.
            let splitKeyWidth = min(keyHeight * 78.0 / 72.0, maxKeyWidthByWidth)
            // Split mode may narrow keys so a half fits under each thumb.
            let resolvedSplit = SplitSizing.resolve(
                mode: state.effectiveSplitMode,
                totalWidth: totalWidth,
                fullKeyWidth: splitKeyWidth,
                fullRailWidth: railWidth(forKeyWidth: splitKeyWidth, totalWidth: totalWidth, minimum: minimumControlExtent),
                spacing: spacing
            )
            /// One keyboard gets the tool column on the side away from the
            /// backspace rail; the keys share what is left. A split keyboard
            /// has no room for it.
            let showsToolColumn = !resolvedSplit.isSplit
            let toolColumnWidth: CGFloat = showsToolColumn ? ToolColumnMetrics.width : 0
            let keysWidth = totalWidth - (showsToolColumn ? toolColumnWidth + spacing : 0)
            let maxKeyWidthBySingle = max((keysWidth - spacing * CGFloat(gridCols)) / CGFloat(gridCols + 1), 1)
            let fullKeyWidth = min(keyHeight * maxKeyAspectRatio, maxKeyWidthBySingle)
            let fullRailWidth = railWidth(forKeyWidth: fullKeyWidth, totalWidth: keysWidth, minimum: minimumControlExtent)
            let splitSizing = resolvedSplit.isSplit
                ? resolvedSplit
                : SplitSizing(isSplit: false, keyWidth: fullKeyWidth, railWidth: fullRailWidth)
            let keyWidth = splitSizing.keyWidth
            // Diamonds, label sizes and gesture thresholds key off the shorter side.
            let keySide = keyHeight

            let shouldDisableCompact = false
            let commandColWidth: CGFloat = 0
            let mainGridWidth = keyWidth * CGFloat(gridCols) + spacing * CGFloat(gridCols - 1)
            let mainGridHeight = keyHeight * CGFloat(gridRows) + spacing * CGFloat(gridRows - 1)

            let spaceBarHeight = max(totalHeight - mainGridHeight, minimumSpaceBarHeight)
            let topInset = max(totalHeight - mainGridHeight - spaceBarHeight, 0)

            let backspaceRailWidth = splitSizing.railWidth
            let sidePadding = max(totalWidth - mainGridWidth - spacing - backspaceRailWidth, 0)

            let armWidth = keySide * 0.40
            let layoutOriginX = state.commandBarOnRight
                ? sidePadding
                : backspaceRailWidth + spacing
            let splitMirror = SplitMirrorLayout.make(
                enabled: splitSizing.isSplit,
                totalWidth: totalWidth,
                keyWidth: keyWidth,
                spacing: spacing,
                primaryGridX: layoutOriginX,
                mainGridWidth: mainGridWidth,
                railWidth: backspaceRailWidth,
                primaryRailOnRight: state.commandBarOnRight
            )
            let hitLayout = LatticeHitLayout(
                originX: layoutOriginX,
                originY: topInset,
                layoutWidth: totalWidth,
                mainGridWidth: mainGridWidth,
                mainGridHeight: mainGridHeight,
                commandColWidth: commandColWidth,
                keySide: keyWidth,
                rowHeight: keyHeight,
                bottomRowHeight: spaceBarHeight,
                commandBarOnRight: state.commandBarOnRight
            )

            let layoutOriginInWindow = outerGeo.frame(in: .global).origin
            let toolColumnFrame = showsToolColumn
                ? CGRect(
                    x: state.commandBarOnRight ? 0 : totalWidth - toolColumnWidth,
                    y: 0,
                    width: toolColumnWidth,
                    height: totalHeight
                )
                : .zero

            ZStack(alignment: .topLeading) {
                bridgeBackground(
                    totalWidth: totalWidth,
                    totalHeight: totalHeight,
                    stripHeight: topInset,
                    mainGridHeight: mainGridHeight,
                    rowHeight: keySide,
                    layoutOriginX: layoutOriginX,
                    mainGridWidth: mainGridWidth,
                    backspaceRailWidth: backspaceRailWidth,
                    railOnRight: state.commandBarOnRight
                )

                latticeKeyboard(
                    layoutWidth: mainGridWidth,
                    mainGridWidth: mainGridWidth,
                    mainGridHeight: mainGridHeight,
                    commandColWidth: commandColWidth,
                    keySide: keyWidth,
                    rowHeight: keyHeight,
                    bottomRowHeight: spaceBarHeight,
                    armWidth: armWidth
                )
                .frame(width: mainGridWidth, height: mainGridHeight)
                .position(x: layoutOriginX + mainGridWidth / 2, y: topInset + mainGridHeight / 2)

                if showsToolColumn {
                    ToolColumnView(
                        items: toolItems,
                        offset: toolOffset,
                        pressedIndex: toolPressedIndex,
                        theme: state.theme
                    )
                    .frame(width: toolColumnFrame.width, height: toolColumnFrame.height)
                    .position(x: toolColumnFrame.midX, y: toolColumnFrame.midY)
                    .allowsHitTesting(false)
                    .onAppear {
                        guard !toolOffsetLoaded else { return }
                        toolOffsetLoaded = true
                        toolOffset = min(
                            max(state.toolColumnOffset, 0),
                            ToolColumnMetrics.maxOffset(itemCount: toolItems.count, height: toolColumnFrame.height)
                        )
                    }
                }

                // Wide screens: a second, draw-only copy on the far side with its
                // backspace rail on the outer edge. Its touches are shifted onto
                // the primary half, so both halves type exactly the same thing.
                if let splitMirror {
                    bridgeBackground(
                        totalWidth: totalWidth,
                        totalHeight: totalHeight,
                        stripHeight: topInset,
                        mainGridHeight: mainGridHeight,
                        rowHeight: keySide,
                        layoutOriginX: splitMirror.gridX,
                        mainGridWidth: mainGridWidth,
                        backspaceRailWidth: backspaceRailWidth,
                        railOnRight: splitMirror.railOnRight
                    )

                    latticeKeyboard(
                        layoutWidth: mainGridWidth,
                        mainGridWidth: mainGridWidth,
                        mainGridHeight: mainGridHeight,
                        commandColWidth: commandColWidth,
                        keySide: keyWidth,
                        rowHeight: keyHeight,
                        bottomRowHeight: spaceBarHeight,
                        armWidth: armWidth,
                        registersRegions: false
                    )
                    .frame(width: mainGridWidth, height: mainGridHeight)
                    .position(x: splitMirror.gridX + mainGridWidth / 2, y: topInset + mainGridHeight / 2)
                }
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
            .onAppear { isSplitShown = splitMirror != nil }
            .onChange(of: splitMirror != nil) { shown in
                isSplitShown = shown
            }
            .onChange(of: state.currentLayer) { _ in
                registerHitLayout(hitLayout)
            }
            .overlay {
                // One UIKit view sees every finger separately. SwiftUI's
                // DragGesture follows a single touch, so when a second thumb
                // landed before the first lifted (normal when typing fast) the
                // second tap was either lost or read as a swipe from the first
                // key, which dropped letters.
                MultiTouchSurface { touch, phase, sample in
                    let point = TouchPointResolver.point(
                        local: sample.local,
                        inWindow: sample.inWindow,
                        surfaceSize: sample.surfaceSize,
                        layoutSize: CGSize(width: totalWidth, height: totalHeight),
                        layoutOriginInWindow: layoutOriginInWindow
                    )
                    // Hit regions must come from the same layout as this
                    // touch. They are normally pushed on a layout change, but
                    // if that update was missed after a resize the keys would
                    // be hit-tested against the old grid until reopening.
                    if phase == .began {
                        syncHitLayout(hitLayout)
                    }
                    let dx = splitTouchOffset(touch, phase: phase, at: point, mirror: splitMirror)
                    handleTouch(
                        touch,
                        phase: phase,
                        at: CGPoint(x: point.x + dx, y: point.y),
                        ctx: GestureLayoutContext(
                            totalWidth: totalWidth,
                            totalHeight: totalHeight,
                            stripHeight: topInset,
                            armWidth: armWidth,
                            keySide: keySide,
                            layoutOriginX: layoutOriginX,
                            mainGridWidth: mainGridWidth,
                            backspaceRailWidth: backspaceRailWidth,
                            toolColumnFrame: toolColumnFrame
                        )
                    )
                    // After handling, so "typed" includes what this touch typed.
                    if state.showTouchDebug, phase == .began || phase == .ended {
                        recordTouchDebug(
                            phase: phase,
                            sample: sample,
                            resolved: point,
                            dx: dx,
                            layoutSize: CGSize(width: totalWidth, height: totalHeight),
                            layoutOriginInWindow: layoutOriginInWindow,
                            hitLayout: hitLayout,
                            isSplit: splitMirror != nil
                        )
                    }
                }
            }
            .overlay {
                if state.showTouchDebug {
                    TouchDebugOverlay(model: state.touchDebug)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if state.showGestureTrail {
                    GestureTrailView(model: state.gestureTrail, theme: state.theme)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topLeading) {
                if let holdPicker {
                    HoldPickerView(
                        picker: holdPicker,
                        fingerX: holdPicker.anchor.x + activeTrailOffsetX,
                        totalWidth: totalWidth,
                        totalHeight: totalHeight,
                        theme: state.theme
                    )
                    .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "keyboard")
        }
        // Fill whatever height the input view really got, up to the chosen
        // height, pinned to the bottom. A fixed height was centered when the
        // system gave less room (landscape adds a home-indicator inset), which
        // pushed the top key row off the top edge and left an empty strip
        // under the space row.
        .frame(maxWidth: .infinity, maxHeight: state.effectiveKeyboardHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .vertical)
        .onDisappear {
            cancelNumberLongPress()
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
        armWidth: CGFloat = 0,
        registersRegions: Bool = true
    ) -> some View {
        let mainX = state.commandBarOnRight ? 0 : commandColWidth
        let diamondSide = min(keySide, rowHeight) * 0.60
        let commandBarCol = state.commandBarOnRight ? 3 : -1

        ZStack(alignment: .topLeading) {
            mainGrid(
                width: mainGridWidth,
                height: mainGridHeight,
                rowHeight: rowHeight,
                armWidth: armWidth,
                registersRegions: registersRegions
            )
                .frame(width: mainGridWidth, height: mainGridHeight)
                .position(x: mainX + mainGridWidth / 2, y: mainGridHeight / 2)

            internalCommandDiamond(
                config: KeyConfig(tap: "", specialAction: .globe, displayLabel: "globe"),
                position: GridPosition(row: 0, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide + spacing / 2, y: rowHeight + spacing / 2),
                updatesGlobe: true,
                isMirror: !registersRegions
            )

            internalCommandDiamond(
                config: KeyConfig(tap: state.currentLayer == .letters ? "123" : "abc", specialAction: .toggleLayer, displayLabel: state.currentLayer == .letters ? "123" : "abc"),
                position: GridPosition(row: 1, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide * 2 + spacing * 1.5, y: rowHeight + spacing / 2),
                updatesGlobe: false,
                isMirror: !registersRegions
            )

            internalCommandDiamond(
                config: KeyConfig(tap: "", specialAction: .dictation, displayLabel: "dictation"),
                position: GridPosition(row: 3, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide * 2 + spacing * 1.5, y: rowHeight * 2 + spacing * 1.5),
                updatesGlobe: false,
                updatesResize: true,
                isMirror: !registersRegions
            )

            internalCommandDiamond(
                config: KeyConfig(tap: "", specialAction: .shift, displayLabel: "shift"),
                position: GridPosition(row: 4, col: commandBarCol),
                size: diamondSide,
                center: CGPoint(x: mainX + keySide + spacing / 2, y: rowHeight * 2 + spacing * 1.5),
                updatesGlobe: false,
                isMirror: !registersRegions
            )
        }
        .frame(width: layoutWidth, height: mainGridHeight, alignment: .topLeading)
    }

    /// The command column for keys of `keyWidth`: one key wide, never below a
    /// usable target, and never wider than what the keys leave free.
    private func railWidth(forKeyWidth keyWidth: CGFloat, totalWidth: CGFloat, minimum: CGFloat) -> CGFloat {
        let gridWidth = keyWidth * CGFloat(gridCols) + spacing * CGFloat(gridCols - 1)
        let available = max(totalWidth - gridWidth - spacing, minimum)
        return min(available, max(keyWidth, minimum))
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
        backspaceRailWidth: CGFloat,
        railOnRight: Bool
    ) -> some View {
        let gridBottom = stripHeight + mainGridHeight
        // The bottom row is drawn below a `spacing` gap like the key rows. Its touch
        // targets still start at the grid bottom, so the gap is not a dead zone.
        let spaceTop = gridBottom + spacing
        let spaceHeight = max(totalHeight - spaceTop, 0)
        let railWidth = max(backspaceRailWidth, 0)
        let railX = railOnRight
            ? layoutOriginX + mainGridWidth + spacing
            : max(layoutOriginX - spacing - railWidth, 0)
        let railHeight = max(mainGridHeight, 0)
        let cornerMinX = railOnRight ? layoutOriginX + mainGridWidth : railX
        let cornerMaxX = railOnRight ? railX + railWidth : layoutOriginX
        let cornerWidth = max(cornerMaxX - cornerMinX, 0)
        let bottomControls = bottomControlMetrics(
            layoutOriginX: layoutOriginX,
            mainGridWidth: mainGridWidth
        )

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(spaceBridgeFill)
                .frame(width: bottomControls.spaceWidth, height: spaceHeight)
                .position(
                    x: bottomControls.spaceX + bottomControls.spaceWidth / 2,
                    y: spaceTop + spaceHeight / 2
                )

            if bottomControls.hasZeroKey {
                Rectangle()
                    .fill(backspaceBridgeFill)
                    .frame(width: bottomControls.zeroWidth, height: spaceHeight)
                    .position(
                        x: bottomControls.zeroX + bottomControls.zeroWidth / 2,
                        y: spaceTop + spaceHeight / 2
                    )

                Text("0")
                    .font(.system(size: min(max(spaceHeight * 0.48, 24), 38), weight: .medium, design: .rounded))
                    .foregroundColor(state.theme.specialTextColor)
                    .commandLabelDepth(for: state.theme)
                    .frame(width: bottomControls.zeroWidth, height: spaceHeight)
                    .position(
                        x: bottomControls.zeroX + bottomControls.zeroWidth / 2,
                        y: spaceTop + spaceHeight / 2
                    )
            }

            Rectangle()
                .fill(backspaceBridgeFill)
                .frame(width: railWidth, height: railHeight)
                .position(x: railX + railWidth / 2, y: stripHeight + railHeight / 2)

            Rectangle()
                .fill(backspaceBridgeFill)
                .frame(width: cornerWidth, height: spaceHeight)
                .position(x: cornerMinX + cornerWidth / 2, y: spaceTop + spaceHeight / 2)
                .overlay {
                    Rectangle()
                        .stroke(state.theme.keyBorder, lineWidth: state.theme.keyBorderWidth)
                        .frame(width: cornerWidth, height: spaceHeight)
                        .position(x: cornerMinX + cornerWidth / 2, y: spaceTop + spaceHeight / 2)
                }

            Image(systemName: "delete.left")
                .font(.system(size: min(railWidth, rowHeight) * 0.42, weight: .medium))
                .foregroundColor(state.theme.specialTextColor)
                .frame(width: railWidth, height: railHeight)
                .position(x: railX + railWidth / 2, y: stripHeight + railHeight / 2)

            Image(systemName: "return.left")
                // At cornerWidth ~61pt / spaceHeight ~90.8pt, 0.42 drew the arrow at
                // ~25.6pt, visibly smaller than the ~30pt space-bar symbol next to it.
                // 0.60 gives ~36.6pt, which still fits comfortably inside the corner block.
                .font(.system(size: min(cornerWidth, spaceHeight) * 0.60, weight: .medium))
                .foregroundColor(state.theme.specialTextColor)
                .commandLabelDepth(for: state.theme)
                .frame(width: cornerWidth, height: spaceHeight)
                .position(x: cornerMinX + cornerWidth / 2, y: spaceTop + spaceHeight / 2)

            Group {
                if state.currentLayer == .letters && state.showCenterLabels {
                    Text("␣")
                        .font(.system(size: min(max(spaceHeight * 0.34, 19), 30), weight: .medium, design: .rounded))
                } else if state.currentLayer != .letters {
                    Image(systemName: "space")
                        .font(.system(size: min(max(spaceHeight * 0.38, 20), 30), weight: .medium))
                }
            }
            .foregroundColor(state.theme.specialTextColor)
            .frame(width: bottomControls.spaceWidth, height: spaceHeight)
            .position(
                x: bottomControls.spaceX + bottomControls.spaceWidth / 2,
                y: spaceTop + spaceHeight / 2
            )
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
        backspaceRailWidth: CGFloat,
        toolColumnFrame: CGRect = .zero
    ) -> ActiveBridge {
        if toolColumnFrame.contains(point) {
            return .toolColumn
        }

        let keySide = rowHeight
        let mainGridHeight = keySide * CGFloat(gridRows) + spacing * CGFloat(gridRows - 1)
        let gridBottom = stripHeight + mainGridHeight
        let railX = state.commandBarOnRight
            ? layoutOriginX + mainGridWidth + spacing
            : 0
        let railEndX = railX + backspaceRailWidth
        let cornerMinX = state.commandBarOnRight ? layoutOriginX + mainGridWidth : 0
        let cornerMaxX = state.commandBarOnRight ? railEndX : layoutOriginX

        if point.x >= cornerMinX,
           point.x <= cornerMaxX,
           point.y >= gridBottom,
           point.y <= totalHeight {
            return .enter
        }

        // Backspace rail mirrors to the side selected by the globe circle gesture.
        if point.x >= railX,
           point.x <= railEndX,
           point.y >= stripHeight,
           point.y < gridBottom {
            return .backspace
        }

        // The unused gutter beside the bottom row is an invisible space target.
        if spaceBarGutterRegion.contains(point) {
            return .space
        }

        // Visible bottom controls retain their existing space/zero split.
        if point.x >= layoutOriginX,
           point.x <= layoutOriginX + mainGridWidth,
           point.y >= gridBottom {
            let bottomControls = bottomControlMetrics(
                layoutOriginX: layoutOriginX,
                mainGridWidth: mainGridWidth
            )
            if bottomControls.hasZeroKey,
               point.x >= bottomControls.zeroX,
               point.x <= bottomControls.zeroX + bottomControls.zeroWidth {
                return .zero
            }
            return .space
        }

        return .none
    }

    // MARK: - Logical Gesture Lifecycle

    /// Routes per-finger touches into the single logical gesture.
    ///
    /// Typing order is touchdown order: when a new finger lands while another
    /// is still down, the earlier gesture is committed where that finger is
    /// now, and the new finger takes over. The earlier finger's later moves
    /// and lift are ignored, so neither tap is lost and the second tap can't
    /// be mistaken for a swipe out of the first key.
    private func handleTouch(
        _ touch: ObjectIdentifier,
        phase: MultiTouchSurface.Phase,
        at point: CGPoint,
        ctx: GestureLayoutContext
    ) {
        switch phase {
        case .began:
            if logicalGestureActive {
                if let last = lastTrackedPoint {
                    finishLogicalGesture(at: last, ctx: ctx)
                } else {
                    abandonStaleGesture()
                }
            }
            primaryTouch = touch
            beginLogicalGesture(at: point, ctx: ctx)
            continueLogicalGesture(at: point, ctx: ctx)
            lastTrackedPoint = point

        case .moved:
            guard touch == primaryTouch, logicalGestureActive else { return }
            continueLogicalGesture(at: point, ctx: ctx)
            lastTrackedPoint = point

        case .ended:
            guard touch == primaryTouch else { return }
            if logicalGestureActive {
                finishLogicalGesture(at: point, ctx: ctx)
            }
            primaryTouch = nil
            lastTrackedPoint = nil

        case .cancelled:
            guard touch == primaryTouch else { return }
            if logicalGestureActive {
                abandonStaleGesture()
            }
            primaryTouch = nil
            lastTrackedPoint = nil
        }
    }

    /// The shift that moves this finger from the split mirror onto the same
    /// spot of the primary half (0 off the mirror). Decided at touchdown and
    /// kept until lift, so a swipe that leaves the mirror keeps its shape.
    private func splitTouchOffset(
        _ touch: ObjectIdentifier,
        phase: MultiTouchSurface.Phase,
        at point: CGPoint,
        mirror: SplitMirrorLayout?
    ) -> CGFloat {
        switch phase {
        case .began:
            let dx = mirror?.offset(forX: point.x) ?? 0
            splitTouchOffsets[touch] = dx == 0 ? nil : dx
            pendingTrailOffsetX = -dx
            // Light up only the half under the finger, not both copies.
            let onMirror = dx != 0
            if state.keyHighlight.isOnMirror != onMirror {
                state.keyHighlight.isOnMirror = onMirror
            }
            return dx
        case .moved:
            return splitTouchOffsets[touch] ?? 0
        case .ended, .cancelled:
            let dx = splitTouchOffsets[touch] ?? 0
            splitTouchOffsets[touch] = nil
            return dx
        }
    }

    private func beginLogicalGesture(at point: CGPoint, ctx: GestureLayoutContext) {
        // The previous gesture has been committed by now, so its trail kept
        // its own shift; this one takes the shift of the finger that landed.
        activeTrailOffsetX = pendingTrailOffsetX
        logicalGestureActive = true
        longPressTriggered = false
        activeBridge = bridgeAt(
            point,
            totalWidth: ctx.totalWidth,
            totalHeight: ctx.totalHeight,
            stripHeight: ctx.stripHeight,
            armWidth: ctx.armWidth,
            rowHeight: ctx.keySide,
            layoutOriginX: ctx.layoutOriginX,
            mainGridWidth: ctx.mainGridWidth,
            backspaceRailWidth: ctx.backspaceRailWidth,
            toolColumnFrame: ctx.toolColumnFrame
        )

        switch activeBridge {
        case .space:
            gestureEngine.touchBegan(at: point)
            spaceCursor.begin(at: point, time: ProcessInfo.processInfo.systemUptime)
        case .backspace:
            backspacePath = [point]
            backspaceScrub.reset(start: point)
        case .none:
            gestureEngine.touchBegan(at: point)
            resetGestureTrail(at: point)
            scheduleHold(at: point, delay: numberHoldDuration)
        case .toolColumn:
            beginToolTouch(at: point, frame: ctx.toolColumnFrame)
        case .enter, .zero:
            break
        }
    }

    private func continueLogicalGesture(at point: CGPoint, ctx: GestureLayoutContext) {
        switch activeBridge {
        case .space:
            gestureEngine.touchMoved(to: point)
            trackSpaceCursor(at: point)
        case .backspace:
            backspacePath.append(point)
            if backspaceScrub.observe(point, keySide: ctx.keySide) {
                onDeleteWord()
            }
        case .none:
            guard !longPressTriggered else {
                if var picker = holdPicker, picker.track(point) {
                    holdPicker = picker
                }
                return
            }
            gestureEngine.touchMoved(to: point)
            if distance(holdAnchor, point) > holdStillnessRadius {
                scheduleHold(at: point, delay: swipeHoldDuration)
            }
            if state.showGestureTrail {
                appendGestureTrailPoint(point)
            } else {
                state.gestureTrailPoints = []
            }
            updateActiveKey(at: point)
        case .toolColumn:
            moveToolTouch(to: point, frame: ctx.toolColumnFrame)
        case .enter, .zero:
            break
        }
    }

    private func finishLogicalGesture(at point: CGPoint, ctx: GestureLayoutContext) {
        let bridge = activeBridge
        logicalGestureActive = false
        cancelNumberLongPress()
        activeBridge = .none
        setActiveKey(nil)

        switch bridge {
        case .toolColumn:
            endToolTouch(at: point, frame: ctx.toolColumnFrame)

        case .enter:
            onEnter()
            state.gestureTrailPoints = []

        case .zero:
            onCharacter("0")
            state.afterCharacterInserted()
            state.gestureTrailPoints = []

        case .backspace:
            backspacePath.append(point)
            if backspaceScrub.observe(point, keySide: ctx.keySide) {
                onDeleteWord()
            }
            if !backspaceScrub.deletedWord {
                switch analyzeBackspacePath(backspacePath, keySide: ctx.keySide) {
                case .single:
                    onBackspace()
                case .word:
                    onDeleteWord()
                case .cancel:
                    break
                }
            }
            backspacePath = []
            backspaceScrub.reset()
            state.gestureTrailPoints = []

        case .space:
            trackSpaceCursor(at: point)
            if spaceCursor.didMoveCursor {
                // The finger already moved the cursor while it was down (a
                // trackpad drag or a word scrub), so lifting adds nothing.
                gestureEngine.touchCancelled()
                spaceCursor = SpaceCursorTracker()
                state.gestureTrailPoints = []
                break
            }
            spaceCursor = SpaceCursorTracker()
            // Let gestureEngine evaluate first — it may recognize a space-swipe gesture.
            let result = gestureEngine.touchEnded(at: point)
            switch result {
            case .specialSwipe(let special) where
                special == .spaceSwipeUp
                || special == .spaceSwipeUpAndBack
                || special == .spaceCursorLeft
                || special == .spaceCursorRight:
                handleGestureResult(result)
            default:
                onCharacter(" ")
            }
            state.gestureTrailPoints = []

        case .none:
            if longPressTriggered {
                longPressTriggered = false
                if let pick = holdPicker?.selected {
                    onCharacter(pick)
                    state.afterCharacterInserted()
                }
                holdPicker = nil
                gestureEngine.touchCancelled()
                state.gestureTrailPoints = []
                return
            }
            if state.showGestureTrail {
                appendGestureTrailPoint(point, force: true)
            }
            let result = gestureEngine.touchEnded(at: point)
            handleGestureResult(result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                state.gestureTrailPoints = []
            }
        }
        longPressTriggered = false
    }

    /// Moves the cursor live while a finger drags or scrubs on the space bar.
    private func trackSpaceCursor(at point: CGPoint) {
        guard let move = spaceCursor.observe(point, time: ProcessInfo.processInfo.systemUptime) else { return }
        switch move {
        case .characters(let offset):
            onMoveCursor(offset)
        case .words(let offset):
            onMoveCursorByWord(offset)
        }
    }

    private func abandonStaleGesture() {
        toolDragStart = nil
        toolPressedIndex = nil
        gestureEngine.touchCancelled()
        cancelNumberLongPress()
        longPressTriggered = false
        holdPicker = nil
        activeBridge = .none
        backspacePath = []
        backspaceScrub.reset()
        spaceCursor = SpaceCursorTracker()
        logicalGestureActive = false
        lastTrackedPoint = nil
        state.gestureTrailPoints = []
        setActiveKey(nil)
    }

    private func recordTouchDebug(
        phase: MultiTouchSurface.Phase,
        sample: MultiTouchSurface.Sample,
        resolved: CGPoint,
        dx: CGFloat,
        layoutSize: CGSize,
        layoutOriginInWindow: CGPoint,
        hitLayout: LatticeHitLayout,
        isSplit: Bool
    ) {
        func f(_ v: CGFloat) -> String { String(format: "%.1f", v) }
        func p(_ pt: CGPoint) -> String { "(\(f(pt.x)),\(f(pt.y)))" }
        func sz(_ s: CGSize) -> String { "\(f(s.width))x\(f(s.height))" }
        let mapped = CGPoint(x: resolved.x + dx, y: resolved.y)
        let key = gestureEngine.keyPosition(at: mapped).map { "r\($0.row)c\($0.col)" } ?? "none"
        let usedWindow = resolved != sample.local
        let engineMatches = registeredHitLayout.key?.layout == hitLayout
        let lines = [
            "\(phase == .began ? "DOWN" : "UP") key \(key) split \(isSplit) dx \(f(dx))",
            "raw \(p(sample.local)) mapped \(p(mapped))",
            "win \(p(sample.inWindow)) origin \(p(layoutOriginInWindow))",
            "surface \(sz(sample.surfaceSize)) layout \(sz(layoutSize))\(usedWindow ? " WINDOW" : "")",
            "grid x \(f(hitLayout.originX)) y \(f(hitLayout.originY)) key \(f(hitLayout.keySide))x\(f(hitLayout.rowHeight)) engine \(engineMatches ? "ok" : "STALE")",
            "typed \(state.touchDebug.typed)",
        ]
        var regions = gestureEngine.debugKeyRegions
            .filter { $0.key.col >= 0 && $0.key.col < gridCols && $0.key.row < gridRows }
            .map(\.value)
        regions.append(gestureEngine.debugSpaceBarRegion)
        state.touchDebug.recordTouch(
            TouchDebugModel.Mark(raw: sample.local, mapped: mapped),
            lines: lines,
            regions: regions
        )
    }

    /// Re-registers the hit regions only when the engine holds a different
    /// layout or layer than the one this touch was drawn with.
    private func syncHitLayout(_ layout: LatticeHitLayout) {
        let key = RegisteredHitLayout.Key(layout: layout, layer: state.currentLayer)
        guard registeredHitLayout.key != key else { return }
        registerHitLayout(layout)
    }

    private func registerHitLayout(_ layout: LatticeHitLayout) {
        registeredHitLayout.key = RegisteredHitLayout.Key(layout: layout, layer: state.currentLayer)
        let commandCol = layout.commandBarOnRight ? 3 : -1
        let mainX = layout.originX
        let originY = layout.originY
        // Diamond hit rects are smaller than the visual to avoid overlapping letter cells.
        let diamondSide = min(layout.keySide, layout.rowHeight) * 0.44
        let diamondHalf = diamondSide / 2
        // Keep the forgiving tap target close to the visible diamond (0.60 of a
        // key). A larger region swallows taps aimed at adjacent letter corners
        // and switches to the number layer instead of typing the letter.
        let commandTapSide = min(layout.keySide, layout.rowHeight) * 0.64
        let commandTapHalf = commandTapSide / 2

        // Letter cells come from the same layout numbers that draw the grid,
        // all in one pass. They used to be written by a GeometryReader per key,
        // and after a size change (fold, rotate, screen switch) this function
        // could run with the old cell frames and write them back, so taps hit
        // the previous grid until the keyboard was reopened.
        var regions: [GridPosition: CGRect] = [:]
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                regions[GridPosition(row: row, col: col)] = CGRect(
                    x: mainX + CGFloat(col) * (layout.keySide + spacing),
                    y: originY + CGFloat(row) * (layout.rowHeight + spacing),
                    width: layout.keySide,
                    height: layout.rowHeight
                )
            }
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
        // Keep the gutter separate: on number layers the zero key lies between
        // it and the visible spacebar, so a single expanded rect would swallow 0.
        let bottomControls = bottomControlMetrics(
            layoutOriginX: layout.originX,
            mainGridWidth: layout.mainGridWidth
        )
        let bottomBridgeStripRect = CGRect(
            x: bottomControls.spaceX,
            y: originY + layout.mainGridHeight,
            width: bottomControls.spaceWidth,
            height: layout.bottomRowHeight
        )
        spaceBarRegion = bottomBridgeStripRect
        spaceBarGutterRegion = layout.spaceBarGutterRegion
        globeRegion = regions[GridPosition(row: 0, col: commandCol)] ?? .zero
        gestureEngine.updateKeyRegions(regions)
        gestureEngine.labeledDirections = { [state] pos in
            Self.assignedSwipeDirections(at: pos, state: state)
        }
        gestureEngine.hiddenTargetDirections = { [state] pos in
            Self.hiddenSymbolDirections(at: pos, state: state)
        }
        gestureEngine.hiddenTargetMinimumReach = { [state] in
            Self.symbolSwipeMinimumReach(state: state)
        }
        gestureEngine.updateSpaceBarRegion(bottomBridgeStripRect, gutterRegion: spaceBarGutterRegion)
        gestureEngine.updateGlobeRegion(globeRegion)
        gestureEngine.updateResizeRegion(regions[GridPosition(row: 3, col: commandCol)] ?? .zero)
        gestureEngine.updateForgivingCommandRegions([
            GridPosition(row: 1, col: commandCol): CGRect(
                x: layerCenter.x - commandTapHalf,
                y: layerCenter.y - commandTapHalf,
                width: commandTapSide,
                height: commandTapSide
            ),
            GridPosition(row: 4, col: commandCol): CGRect(
                x: shiftCenter.x - commandTapHalf,
                y: shiftCenter.y - commandTapHalf,
                width: commandTapSide,
                height: commandTapSide
            )
        ])
    }

    /// Directions on a main-grid key that type something the user can see or
    /// has learned: the key's own swipes, the symbol overlay while it is
    /// shown, and the persistent tab and ".com" shortcuts.
    private static func assignedSwipeDirections(at pos: GridPosition, state: KeyboardState) -> Set<SwipeDirection> {
        let grid = state.currentGrid
        guard grid.indices.contains(pos.row), grid[pos.row].indices.contains(pos.col) else { return [] }

        var directions = Set(grid[pos.row][pos.col].swipes.keys)
        if state.currentLayer == .letters && state.isSymbolOverlayActive && state.showSymbolLabels {
            directions.formUnion(KeyboardLayoutData.activeSymbolOverlayGrid()[pos.row][pos.col].swipes.keys)
        }
        if pos == GridPosition(row: 2, col: 0) {
            directions.insert(.bottomRight)
        }
        if state.currentLayer == .letters && state.isURLField && pos == KeyboardLayoutData.dotComPosition {
            directions.insert(.bottom)
        }
        return directions
    }

    /// Symbol-overlay directions on the letter layer that still type their
    /// symbol while its label is hidden (see `hiddenSymbolSwipe`).
    private static func hiddenSymbolDirections(at pos: GridPosition, state: KeyboardState) -> Set<SwipeDirection> {
        guard state.currentLayer == .letters else { return [] }
        let overlay = KeyboardLayoutData.activeSymbolOverlayGrid()
        guard overlay.indices.contains(pos.row), overlay[pos.row].indices.contains(pos.col) else { return [] }
        return Set(overlay[pos.row][pos.col].swipes.keys)
            .subtracting(assignedSwipeDirections(at: pos, state: state))
    }

    private func bottomControlMetrics(
        layoutOriginX: CGFloat,
        mainGridWidth: CGFloat
    ) -> BottomControlMetrics {
        guard state.currentLayer != .letters else {
            return BottomControlMetrics(
                spaceX: layoutOriginX,
                spaceWidth: mainGridWidth,
                zeroX: layoutOriginX,
                zeroWidth: 0
            )
        }

        let spaceWidth = mainGridWidth / 3
        let zeroWidth = max(mainGridWidth - spaceWidth - spacing, 0)
        if state.commandBarOnRight {
            return BottomControlMetrics(
                spaceX: layoutOriginX + zeroWidth + spacing,
                spaceWidth: spaceWidth,
                zeroX: layoutOriginX,
                zeroWidth: zeroWidth
            )
        }
        return BottomControlMetrics(
            spaceX: layoutOriginX,
            spaceWidth: spaceWidth,
            zeroX: layoutOriginX + spaceWidth + spacing,
            zeroWidth: zeroWidth
        )
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
        updatesResize: Bool = false,
        isMirror: Bool = false
    ) -> some View {
        ActiveKeyReader(highlight: state.keyHighlight, position: position, isMirror: isMirror) { isActive in
            DiamondCommandKeyView(
                config: config,
                isActive: isActive,
                isShifted: config.specialAction == .shift ? state.isShifted : false,
                isCapsLocked: config.specialAction == .shift ? state.isCapsLocked : false,
                theme: state.theme,
                cornerRadius: state.keyCornerRadius
            )
        }
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
    private func mainGrid(
        width: CGFloat,
        height: CGFloat,
        rowHeight: CGFloat,
        armWidth: CGFloat = 0,
        registersRegions: Bool = true
    ) -> some View {
        let colWidth = max((width - spacing * CGFloat(gridCols - 1)) / CGFloat(gridCols), 1)
        let grid = state.currentGrid
        let isSymbolOverlay = state.currentLayer == .letters && state.isSymbolOverlayActive && state.showSymbolLabels
        let showCenter = state.currentLayer == .letters ? state.showCenterLabels : true
        let showSwipes = state.currentLayer == .letters ? state.showCenterLabels : state.showSymbolLabels

        VStack(spacing: spacing) {
            ForEach(0..<gridRows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridCols, id: \.self) { col in
                        let pos = GridPosition(row: row, col: col)
                        let config = grid[row][col]
                        let visualConfig = isSymbolOverlay ? KeyboardLayoutData.activeSymbolOverlayGrid()[row][col] : config
                        let letterSwipeLabels = isSymbolOverlay ? KeyboardLayoutData.activeLetterGrid()[row][col].swipes : nil
                        let labelShift: CGFloat = 0

                        ActiveKeyReader(highlight: state.keyHighlight, position: pos, isMirror: !registersRegions) { isActive in
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
                        }
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

                ActiveKeyReader(highlight: state.keyHighlight, position: backspacePos) { isActive in
                    DeleteColumnKeyView(
                        isActive: isActive,
                        side: side,
                        theme: state.theme,
                        cornerRadius: state.keyCornerRadius
                    )
                }
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
                    ActiveKeyReader(highlight: state.keyHighlight, position: GridPosition(row: idx, col: state.commandBarOnRight ? 3 : -1)) { isActive in
                        DiamondCommandKeyView(
                            config: config,
                            isActive: isActive,
                            theme: state.theme,
                            cornerRadius: state.keyCornerRadius
                        )
                    }
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
            ActiveKeyReader(highlight: state.keyHighlight, position: GridPosition(row: 3, col: 0)) { isActive in
                SpaceBarView(
                    isActive: isActive,
                    theme: state.theme,
                    cornerRadius: state.keyCornerRadius
                )
            }
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
            ActiveKeyReader(highlight: state.keyHighlight, position: pos) { isActive in
                DiamondCommandKeyView(
                    config: KeyConfig(tap: "", specialAction: .enter, displayLabel: "return"),
                    isActive: isActive,
                    theme: state.theme,
                    cornerRadius: state.keyCornerRadius
                )
            }
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
            setActiveKey(pos)
            return
        }
        if spaceBarRegion.contains(point) {
            setActiveKey(GridPosition(row: 3, col: 0))
        }
    }

    /// Runs on every touch sample. A @Published write re-renders the whole
    /// keyboard even when the value is unchanged, so only write on a change.
    private func setActiveKey(_ pos: GridPosition?) {
        if state.activeKeyPosition != pos {
            state.activeKeyPosition = pos
        }
        if pos == nil, state.swipeDirection != nil {
            state.swipeDirection = nil
        }
    }

    // MARK: - Tool column

    private var toolItems: [ToolColumnItem] {
        ToolColumnItem.items(emoji: state.toolEmoji)
    }

    private func beginToolTouch(at point: CGPoint, frame: CGRect) {
        let now = ProcessInfo.processInfo.systemUptime
        toolDragStart = (toolOffset, point.y)
        toolSamples = [(point.y, now)]
        toolDidScroll = false
        toolPressedIndex = ToolColumnMetrics.index(
            atY: point.y - frame.minY, offset: toolOffset, itemCount: toolItems.count
        )
    }

    private func moveToolTouch(to point: CGPoint, frame: CGRect) {
        guard let start = toolDragStart else { return }
        let dy = point.y - start.y
        if !toolDidScroll, abs(dy) > ToolColumnMetrics.tapSlop {
            toolDidScroll = true
            toolPressedIndex = nil
        }
        guard toolDidScroll else { return }
        // Dragging the finger up moves the list up: further down it.
        toolOffset = ToolColumnMetrics.dragged(
            start.offset - dy, itemCount: toolItems.count, height: frame.height
        )
        let now = ProcessInfo.processInfo.systemUptime
        toolSamples.append((point.y, now))
        toolSamples.removeAll { now - $0.time > 0.1 }
    }

    private func endToolTouch(at point: CGPoint, frame: CGRect) {
        defer {
            toolDragStart = nil
            toolPressedIndex = nil
            toolSamples = []
        }
        guard toolDragStart != nil else { return }
        let items = toolItems

        if !toolDidScroll {
            if let index = ToolColumnMetrics.index(atY: point.y - frame.minY, offset: toolOffset, itemCount: items.count) {
                performToolItem(items[index])
            }
            return
        }

        var velocity: CGFloat = 0
        if let first = toolSamples.first, let last = toolSamples.last, last.time - first.time > 0.008 {
            // Finger moving up (negative dy) scrolls further down the list.
            velocity = -(last.y - first.y) / CGFloat(last.time - first.time)
        }
        let resting = ToolColumnMetrics.resting(
            offset: toolOffset, velocity: velocity, itemCount: items.count, height: frame.height
        )
        withAnimation(.interpolatingSpring(stiffness: 170, damping: 24)) {
            toolOffset = resting
        }
        state.toolColumnOffset = resting
    }

    private func performToolItem(_ item: ToolColumnItem) {
        switch item {
        case .undo:
            onToolAction(.undo)
        case .redo:
            onToolAction(.redo)
        case .copy:
            onToolAction(.copy)
        case .paste:
            if let content = UIPasteboard.general.string, !content.isEmpty {
                onCharacter(content)
                state.afterCharacterInserted()
            }
        case .emoji(let emoji):
            onCharacter(emoji)
            state.recordEmojiUse(emoji)
            state.afterCharacterInserted()
        }
    }

    // MARK: - Hold: numbers and accents

    /// Arms the hold timer for a finger resting at `point`. Holding a key's
    /// own letter offers its number and accents; resting at the end of a swipe
    /// offers the swiped letter's accents. A key with no accents keeps the old
    /// behaviour and types its number as soon as the hold fires.
    private func scheduleHold(at point: CGPoint, delay: TimeInterval) {
        cancelNumberLongPress()
        holdAnchor = point
        guard state.currentLayer == .letters,
              let startPoint = gestureEngine.points.first,
              let startKey = gestureEngine.keyPosition(at: startPoint),
              (0..<gridRows).contains(startKey.row),
              (0..<gridCols).contains(startKey.col) else {
            return
        }

        let task = DispatchWorkItem {
            guard gestureEngine.hasActiveGesture, activeBridge == .none, !longPressTriggered else { return }
            openHold(at: lastTrackedPoint ?? point)
        }
        longPressTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func openHold(at point: CGPoint) {
        let grid = state.currentGrid
        func key(_ pos: GridPosition) -> KeyConfig? {
            guard (0..<gridRows).contains(pos.row),
                  (0..<gridCols).contains(pos.col),
                  pos.row < grid.count, pos.col < grid[pos.row].count else { return nil }
            let config = grid[pos.row][pos.col]
            return config.specialAction == nil ? config : nil
        }

        switch gestureEngine.provisionalResult(at: point) {
        case .tap(let pos):
            guard let config = key(pos) else { return }
            let number = String(pos.row * gridCols + pos.col + 1)
            let choices = HoldPicker.choicesForHeldKey(letter: state.applyCase(config.tap), number: number)
            longPressTriggered = true
            if choices.count == 1 {
                onCharacter(number)
                state.afterCharacterInserted()
            } else {
                showHoldPicker(choices, at: point)
            }

        case .swipe(let pos, let direction, _):
            openSwipeHold(key(pos)?.swipes[direction], uppercase: false, at: point)

        case .swipeBack(let pos, let direction, _):
            openSwipeHold(key(pos)?.swipes[direction], uppercase: true, at: point)

        default:
            return
        }
    }

    /// Accents for a letter reached by a swipe; a swipe that came back is a
    /// capital, as it is when it lifts.
    private func openSwipeHold(_ letter: String?, uppercase: Bool, at point: CGPoint) {
        guard let letter else { return }
        let cased = uppercase ? letter.uppercased() : state.applyCase(letter)
        let choices = Diacritics.variants(of: cased)
        guard !choices.isEmpty else { return }
        longPressTriggered = true
        showHoldPicker(choices, at: point)
    }

    private func showHoldPicker(_ choices: [String], at point: CGPoint) {
        holdPicker = HoldPicker(choices: choices, anchor: point, cellWidth: HoldPickerView.cellStride)
        state.gestureTrailPoints = []
        setActiveKey(nil)
    }

    private func cancelNumberLongPress() {
        longPressTask?.cancel()
        longPressTask = nil
    }

    // MARK: - Gesture Trail

    private func resetGestureTrail(at point: CGPoint) {
        state.gestureTrailPoints = state.showGestureTrail ? [trailPoint(point)] : []
    }

    /// Where the finger really is, for a point in hit-test space.
    private func trailPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + activeTrailOffsetX, y: point.y)
    }

    private func appendGestureTrailPoint(_ hitPoint: CGPoint, force: Bool = false) {
        let point = trailPoint(hitPoint)
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

        case .swipe(let pos, let dir, let reach):
            handleSwipe(from: pos, direction: dir, uppercase: false, reach: reach)

        case .swipeBack(let pos, let dir, let reach):
            handleSwipe(from: pos, direction: dir, uppercase: true, reach: reach)

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

    private func handleSwipe(from pos: GridPosition, direction: SwipeDirection, uppercase: Bool, reach: CGFloat) {
        if handleCommandSwipe(from: pos, isBackAndForth: uppercase) {
            return
        }

        let grid = state.currentGrid
        guard pos.row >= 0 && pos.row < grid.count,
              pos.col >= 0 && pos.col < grid[pos.row].count else { return }

        let config = grid[pos.row][pos.col]

        // A visible number-layer symbol owns its direction. Persistent commands
        // and hidden letter fallbacks only apply when that cell is unassigned.
        if state.currentLayer != .letters, let char = config.swipes[direction] {
            insertSwipeCharacter(char, uppercase: uppercase, capitalFallback: config.tap)
            return
        }

        // Check for special overlays first
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

        if let char = config.swipes[direction] {
            insertSwipeCharacter(char, uppercase: uppercase, capitalFallback: config.tap)
            return
        }

        // Symbol-overlay swipes stay reachable whether or not their labels are
        // showing. While hidden they are unlabeled targets, so they demand a
        // committed swipe — a fast-typing wobble off a tap must not reach them.
        // Never on an uppercase swipe-back: that gesture means a letter.
        if !uppercase, reach >= symbolSwipeMinimumReach,
           let char = hiddenSymbolSwipe(from: pos, direction: direction) {
            insertSwipeCharacter(char, uppercase: false)
            return
        }

        if let char = numberLayerLetterSwipe(from: pos, direction: direction) {
            insertSwipeCharacter(char, uppercase: uppercase, capitalFallback: config.tap)
            return
        }

        // Unassigned direction: the finger wobbled off a plain tap or a circle
        // fell short. Type the key's base character instead of dropping input.
        if config.specialAction == nil, !config.tap.isEmpty {
            insertSwipeCharacter(config.tap, uppercase: uppercase, capitalFallback: config.tap)
        }
    }

    /// How far a swipe must travel, in key half-sides, to select a symbol whose
    /// label is not currently drawn. Visible labels fire at normal sensitivity;
    /// this only guards the unlabeled ones.
    private var symbolSwipeMinimumReach: CGFloat {
        Self.symbolSwipeMinimumReach(state: state)
    }

    private static func symbolSwipeMinimumReach(state: KeyboardState) -> CGFloat {
        state.isSymbolOverlayActive ? 0 : 0.80
    }

    private func insertSwipeCharacter(_ char: String, uppercase: Bool, capitalFallback: String = "") {
        guard uppercase else {
            onCharacter(state.applyCase(char))
            state.afterCharacterInserted()
            return
        }

        // An uppercase gesture — a loop, or a swipe that came back — is a
        // request for a capital. Punctuation has none, so rather than typing a
        // symbol the gesture never meant to reach, fall back to the key's own
        // letter. On the number layer the fallback is a digit, which has no
        // capital either, so the symbol stands.
        onCharacter(Self.capital(of: char, orElse: capitalFallback))
        state.afterCharacterInserted()
    }

    /// The capital of `char`, or of `fallback` when `char` has no distinct
    /// uppercase form. Returns `char` unchanged when neither does.
    private static func capital(of char: String, orElse fallback: String) -> String {
        let uppercased = char.uppercased()
        if uppercased != char { return uppercased }

        let uppercasedFallback = fallback.uppercased()
        if uppercasedFallback != fallback { return uppercasedFallback }

        return char
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

    private func numberLayerLetterSwipe(from pos: GridPosition, direction: SwipeDirection) -> String? {
        guard state.currentLayer != .letters else { return nil }
        let letterGrid = KeyboardLayoutData.activeLetterGrid()
        guard pos.row >= 0 && pos.row < letterGrid.count,
              pos.col >= 0 && pos.col < letterGrid[pos.row].count else {
            return nil
        }

        return letterGrid[pos.row][pos.col].swipes[direction]
    }

    private func handleCommandSwipe(from pos: GridPosition, isBackAndForth _: Bool) -> Bool {
        guard pos.col == 3 || pos.col == -1 else { return false }
        let commands = state.currentCommandBar
        guard pos.row >= 0 && pos.row < commands.count else { return false }
        guard commands[pos.row].specialAction == .backspace else { return false }

        onDeleteWord()
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
            // The small diamond between the middle and right keys. The big
            // return key sits in the corner, so this one starts dictation.
            handleSpecialAction(.dictation)
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
        case .dictation:
            onDictation?()
        }
    }

    private func handleSpecialSwipe(_ special: GestureResult.SpecialSwipe) {
        switch special {
        case .spaceSwipeUp:
            state.toggleSymbolsOnly()
        case .spaceSwipeUpAndBack:
            state.toggleCenterLabels()
        case .spaceCursorLeft:
            onMoveCursor(-1)
        case .spaceCursorRight:
            onMoveCursor(1)
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
        case .globeBackAndForth:
            state.toggleSplit(currentlySplit: isSplitShown)
        }
    }
}

private struct GestureTrailView: View {
    @ObservedObject var model: GestureTrailModel
    let theme: KeyboardTheme

    private var points: [CGPoint] { model.points }

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

/// Outlines what the gesture engine hit-tests against, and marks the last
/// touches: yellow where UIKit put the finger, green where it was hit-tested
/// (on the primary half when the touch was on the split mirror).
private struct TouchDebugOverlay: View {
    @ObservedObject var model: TouchDebugModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.regions.enumerated()), id: \.offset) { _, rect in
                Rectangle()
                    .stroke(Color.red, lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            ForEach(Array(model.marks.enumerated()), id: \.offset) { idx, mark in
                let alpha = Double(idx + 1) / Double(max(model.marks.count, 1))
                Circle().fill(Color.yellow.opacity(alpha))
                    .frame(width: 10, height: 10)
                    .position(mark.raw)
                Circle().stroke(Color.green.opacity(alpha), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .position(mark.mapped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.white)
            .padding(3)
            .background(Color.black.opacity(0.7))
            .fixedSize()
        }
    }
}

private final class RegisteredHitLayout {
    struct Key: Equatable {
        let layout: LatticeHitLayout
        let layer: KeyboardLayer
    }

    var key: Key?
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

    var spaceBarGutterRegion: CGRect {
        let gridEndX = originX + mainGridWidth
        return CGRect(
            x: commandBarOnRight ? 0 : gridEndX,
            y: originY + mainGridHeight,
            width: max(commandBarOnRight ? originX : layoutWidth - gridEndX, 0),
            height: bottomRowHeight
        )
    }
}

// MARK: - Key Highlight

/// Renders `content` with whether `position` is the pressed key. It listens to
/// the highlight on its own, so a press re-renders only the key it lands on
/// and the key it leaves, not the whole keyboard.
private struct ActiveKeyReader<Content: View>: View {
    let highlight: KeyHighlightModel
    let position: GridPosition
    /// Whether this key is drawn on the split keyboard's mirror half.
    var isMirror: Bool = false
    @ViewBuilder let content: (Bool) -> Content
    @State private var isActive = false

    var body: some View {
        content(isActive)
            .onReceive(
                highlight.$position
                    .combineLatest(highlight.$isOnMirror)
                    .map { [position, isMirror] in $0.0 == position && $0.1 == isMirror }
                    .removeDuplicates()
            ) { active in
                if isActive != active {
                    isActive = active
                }
            }
    }
}

// MARK: - Multi-touch Surface

/// A transparent UIKit view that reports every finger on its own, identified
/// across its lifetime, in the view's own coordinates (the same space as the
/// "keyboard" coordinate space it overlays).
struct MultiTouchSurface: UIViewRepresentable {
    enum Phase {
        case began, moved, ended, cancelled
    }

    /// A finger's position, read both locally and in window coordinates,
    /// with the size this view had when it was read.
    struct Sample {
        let local: CGPoint
        let inWindow: CGPoint
        let surfaceSize: CGSize
    }

    let onTouch: (ObjectIdentifier, Phase, Sample) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onTouch = onTouch
    }

    final class TouchView: UIView {
        var onTouch: ((ObjectIdentifier, Phase, Sample) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            isExclusiveTouch = false
            backgroundColor = .clear
            isOpaque = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .began)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .moved)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .ended)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches, .cancelled)
        }

        private func report(_ touches: Set<UITouch>, _ phase: Phase) {
            // Fingers that change in the same frame are replayed oldest first.
            for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
                let sample = Sample(
                    local: touch.location(in: self),
                    inWindow: touch.location(in: nil),
                    surfaceSize: bounds.size
                )
                onTouch?(ObjectIdentifier(touch), phase, sample)
            }
        }
    }
}

private struct GestureLayoutContext {
    let totalWidth: CGFloat
    let totalHeight: CGFloat
    let stripHeight: CGFloat
    let armWidth: CGFloat
    let keySide: CGFloat
    let layoutOriginX: CGFloat
    let mainGridWidth: CGFloat
    let backspaceRailWidth: CGFloat
    var toolColumnFrame: CGRect = .zero
}

private struct BottomControlMetrics {
    let spaceX: CGFloat
    let spaceWidth: CGFloat
    let zeroX: CGFloat
    let zeroWidth: CGFloat

    var hasZeroKey: Bool { zeroWidth > 0 }
}

private struct BackspaceScrubTracker {
    private(set) var deletedWord = false
    private var start: CGPoint?
    private var isArmed = false

    mutating func reset(start: CGPoint? = nil) {
        self.start = start
        isArmed = false
        deletedWord = false
    }

    mutating func observe(_ point: CGPoint, keySide: CGFloat) -> Bool {
        guard let start else { return false }
        let horizontal = abs(point.x - start.x)
        let vertical = abs(point.y - start.y)
        let outwardThreshold = max(keySide * 0.42, 28)
        let returnThreshold = max(keySide * 0.18, 14)

        if !isArmed {
            if horizontal >= outwardThreshold, horizontal > vertical * 1.15 {
                isArmed = true
            }
            return false
        }

        guard hypot(horizontal, vertical) <= returnThreshold else { return false }
        isArmed = false
        deletedWord = true
        return true
    }
}

enum ActiveBridge: Equatable {
    case none, backspace, space, zero, enter, toolColumn
}

/// What a tap on the tool column asks the controller to do. Paste and emoji
/// go through `onCharacter` like any other typing.
enum ToolColumnAction: Equatable {
    case undo, redo, copy
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

// MARK: - Hold Picker

/// The strip of a held letter's number and accents, drawn above the finger.
/// The first choice opens under the finger; sliding sideways moves along it.
struct HoldPickerView: View {
    let picker: HoldPicker
    let fingerX: CGFloat
    let totalWidth: CGFloat
    let totalHeight: CGFloat
    let theme: KeyboardTheme

    static let cellWidth: CGFloat = 36
    static let cellGap: CGFloat = 2
    static var cellStride: CGFloat { cellWidth + cellGap }
    private let cellHeight: CGFloat = 46
    private let padding: CGFloat = 4
    /// Clearance between the strip and the finger's contact point, so the
    /// thumb does not hide the choice it is on.
    private let fingerClearance: CGFloat = 34

    var body: some View {
        let count = CGFloat(picker.choices.count)
        let width = count * Self.cellWidth + (count - 1) * Self.cellGap + padding * 2
        let height = cellHeight + padding * 2
        let preferredX = fingerX - padding - CGFloat(picker.initialIndex) * Self.cellStride - Self.cellWidth / 2
        let x = min(max(preferredX, 2), max(totalWidth - width - 2, 2))
        let above = picker.anchor.y - fingerClearance - height
        let y = above >= 2 ? above : min(picker.anchor.y + fingerClearance, totalHeight - height - 2)

        HStack(spacing: Self.cellGap) {
            ForEach(Array(picker.choices.enumerated()), id: \.offset) { index, choice in
                let isSelected = index == picker.selectedIndex
                Text(choice)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? theme.keyboardBackground : theme.tapColor)
                    .frame(width: Self.cellWidth, height: cellHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? theme.tapColor : Color.clear)
                    )
            }
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.keyBackground)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.keyBorder, lineWidth: 1)
        )
        .offset(x: x, y: y)
    }
}

// MARK: - Tool Column View

/// The scrolling wheel beside the keys. Rows shrink and fade toward the top
/// and bottom edges so it reads as a wheel and the next row always peeks in.
/// Touches are handled by the keyboard's touch surface, not here.
private struct ToolColumnView: View {
    let items: [ToolColumnItem]
    let offset: CGFloat
    let pressedIndex: Int?
    let theme: KeyboardTheme

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let cell = min(width - 10, ToolColumnMetrics.rowHeight - 4)
            let maxOffset = ToolColumnMetrics.maxOffset(itemCount: items.count, height: height)

            ZStack(alignment: .topLeading) {
                theme.emptyColumnBackground

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let centerY = ToolColumnMetrics.edgeInset
                        + CGFloat(index) * ToolColumnMetrics.rowHeight
                        + ToolColumnMetrics.rowHeight / 2
                        - offset
                    let distance = min(abs(centerY - height / 2) / max(height / 2, 1), 1)
                    toolCell(item, size: cell, pressed: index == pressedIndex)
                        .scaleEffect(1 - 0.22 * distance * distance)
                        .opacity(1 - 0.55 * distance * distance)
                        .position(x: width / 2, y: centerY)
                }

                // Fade the rows into the edges like a wheel.
                VStack(spacing: 0) {
                    LinearGradient(colors: [theme.emptyColumnBackground, theme.emptyColumnBackground.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [theme.emptyColumnBackground.opacity(0), theme.emptyColumnBackground],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                }

                if maxOffset > 0 {
                    let track = height - 20
                    let content = ToolColumnMetrics.contentHeight(itemCount: items.count)
                    let thumb = max(track * height / content, 16)
                    let progress = min(max(offset / maxOffset, 0), 1)
                    Capsule()
                        .fill(theme.tapColor.opacity(0.55))
                        .frame(width: 3, height: thumb)
                        .position(x: width - 3, y: 10 + thumb / 2 + (track - thumb) * progress)
                }
            }
            .clipped()
        }
    }

    @ViewBuilder
    private func toolCell(_ item: ToolColumnItem, size: CGFloat, pressed: Bool) -> some View {
        VStack(spacing: 2) {
            if case .emoji(let emoji) = item {
                Text(emoji).font(.system(size: size * 0.5))
            } else if let symbol = item.symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.32, weight: .medium))
                    .foregroundColor(theme.specialTextColor)
                if let caption = item.caption {
                    Text(caption)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(theme.swipeColor)
                }
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(pressed ? theme.activeKeyBackground : theme.keyBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.keyBorder, lineWidth: 1)
        )
    }
}
