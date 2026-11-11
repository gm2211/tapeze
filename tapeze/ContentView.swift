import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(KeyboardState.showGestureTrailDefaultsKey, store: KeyboardState.settingsDefaults) private var showGestureTrail = true
    @AppStorage(KeyboardState.keyCornerRadiusDefaultsKey, store: KeyboardState.settingsDefaults) private var keyCornerRadius = Double(KeyboardState.defaultKeyCornerRadius)
    @AppStorage(KeyboardState.themeDefaultsKey, store: KeyboardState.settingsDefaults) private var selectedThemeID = KeyboardTheme.tapeze.id
    @State private var testText: String = ""
    @State private var isLayoutEditorPresented = false
    @State private var keyboardReadsSettings = true
    @StateObject private var previewState = KeyboardState(isPreview: true)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                settingsView
                previewView
                setupInstructionsView
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            refreshKeyboardReadsSettings()
            previewState.resetLearningPreview()
            previewState.showGestureTrail = showGestureTrail
            previewState.keyCornerRadius = CGFloat(keyCornerRadius)
            previewState.selectedThemeID = selectedThemeID
        }
        .onChange(of: showGestureTrail) { newValue in
            previewState.showGestureTrail = newValue
        }
        .onChange(of: keyCornerRadius) { newValue in
            previewState.keyCornerRadius = CGFloat(newValue)
        }
        .onChange(of: selectedThemeID) { newValue in
            previewState.selectedThemeID = newValue
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                refreshKeyboardReadsSettings()
                previewState.resetLearningPreview()
            }
        }
        .sheet(isPresented: $isLayoutEditorPresented, onDismiss: {
            previewState.refreshLayout()
        }) {
            LayoutEditorView(theme: previewState.theme) {
                previewState.refreshLayout()
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("tapeze")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Compact gesture keyboard setup and preview.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Keyboard Preview")
                    .font(.headline)

                Text("Try the keyboard below with the selected settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ZStack {
                keyboardPreviewBackdrop

                KeyboardView(
                    state: previewState,
                    onCharacter: { char in testText += char },
                    onBackspace: {
                        if !testText.isEmpty { testText.removeLast() }
                    },
                    onDeleteWord: deletePreviousPreviewWord,
                    onDeleteLine: deleteCurrentPreviewLine,
                    onEnter: { testText += "\n" },
                    onMoveCursor: { _ in },
                    onNextKeyboard: nil
                )
            }
            .frame(height: previewState.keyboardHeight)
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(keyCornerRadius), style: .continuous))

            TextField("Type here to test...", text: $testText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var keyboardPreviewBackdrop: some View {
        Color.clear
    }

    private func deletePreviousPreviewWord() {
        guard !testText.isEmpty else { return }

        while let last = testText.last, last.isWhitespace, last != "\n" {
            testText.removeLast()
        }

        var removedWordCharacter = false
        while let last = testText.last, !last.isWhitespace {
            testText.removeLast()
            removedWordCharacter = true
        }

        if !removedWordCharacter, !testText.isEmpty {
            testText.removeLast()
        }
    }

    private func deleteCurrentPreviewLine() {
        guard !testText.isEmpty else { return }

        var removedCharacter = false
        while let last = testText.last, last != "\n" {
            testText.removeLast()
            removedCharacter = true
        }

        if !removedCharacter, !testText.isEmpty {
            testText.removeLast()
        }
    }

    private var setupInstructionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Instructions")
                .font(.headline)

            instructionRow(number: 1, text: "Open Settings → General → Keyboard → Keyboards")
            instructionRow(number: 2, text: "Tap \"Add New Keyboard...\"")
            instructionRow(number: 3, text: "Select \"tapeze\"")
            instructionRow(number: 4, text: "Tap \"tapeze\" and turn on \"Allow Full Access\" so it picks up your color and other settings")
            instructionRow(number: 5, text: "Open Notes or the test field below")
            instructionRow(number: 6, text: "Long-press 🌐 and select \"tapeze\"")

            Text("Some system fields, including password fields and Safari's address bar, may force Apple's keyboard.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                if !keyboardReadsSettings {
                    fullAccessNotice
                }

                HStack(spacing: 8) {
                    ForEach(KeyboardTheme.all) { theme in
                        Button {
                            selectedThemeID = theme.id
                        } label: {
                            ThemeChoice(theme: theme, isSelected: selectedThemeID == theme.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(theme.name) theme")
                        .accessibilityAddTraits(selectedThemeID == theme.id ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Edge softness")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(Int(keyCornerRadius.rounded())) px")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { keyCornerRadius },
                        set: { newValue in
                            keyCornerRadius = newValue
                            previewState.keyCornerRadius = CGFloat(newValue)
                        }
                    ),
                    in: 0...14,
                    step: 1
                )
            }

            Toggle("Show gesture trail", isOn: $showGestureTrail)
                .font(.subheadline)

            Button {
                isLayoutEditorPresented = true
            } label: {
                Label("Edit layout", systemImage: "square.grid.3x3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(sectionBackground)
    }

    private func refreshKeyboardReadsSettings() {
        keyboardReadsSettings = KeyboardState.settingsDefaults.bool(forKey: KeyboardState.keyboardReadsSettingsDefaultsKey)
    }

    /// Shown until the keyboard has appeared once with Full Access. Without it
    /// iOS keeps the keyboard from reading these settings, so a new color shows
    /// in the preview but not in the real keyboard.
    private var fullAccessNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("The keyboard can't see these settings yet", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
            Text("Turn on Allow Full Access for tapeze, then switch to the tapeze keyboard once. Until then it keeps the default color. tapeze never sends what you type anywhere.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.callout.weight(.bold))
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ThemeChoice: View {
    let theme: KeyboardTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.keyGradientTop ?? theme.keyBackground,
                                theme.keyGradientBottom ?? theme.keyBackground
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(theme.tapColor)
                    .frame(width: 17, height: 17)
                    .offset(x: -12, y: -7)

                Circle()
                    .fill(theme.swipeColor)
                    .frame(width: 10, height: 10)
                    .offset(x: 15, y: 10)
            }
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? theme.tapColor : theme.keyBorder.opacity(0.65), lineWidth: isSelected ? 2.5 : 1)
            )

            Text(theme.name)
                .font(.caption2.weight(isSelected ? .bold : .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private enum LayoutEditorLayer: String, CaseIterable, Identifiable {
    case letters
    case symbols
    case numbers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letters: return "Letters"
        case .symbols: return "Symbols"
        case .numbers: return "Numbers"
        }
    }
}

private struct LayoutCellReference {
    let layer: LayoutEditorLayer
    let row: Int
    let col: Int
    let position: KeyCellPosition

    init(layer: LayoutEditorLayer, row: Int, col: Int, position: KeyCellPosition) {
        self.layer = layer
        self.row = row
        self.col = col
        self.position = position
    }

    init?(payload: String) {
        let parts = payload.split(separator: "|").map(String.init)
        guard parts.count == 4,
              let layer = LayoutEditorLayer(rawValue: parts[0]),
              let row = Int(parts[1]),
              let col = Int(parts[2]),
              let position = KeyCellPosition(rawValue: parts[3]) else {
            return nil
        }

        self.layer = layer
        self.row = row
        self.col = col
        self.position = position
    }

    var payload: String {
        "\(layer.rawValue)|\(row)|\(col)|\(position.rawValue)"
    }
}


/// The layout editor works on one key at a time: a small map of all nine keys
/// picks the key, and that key fills the width of the screen with nine large
/// slots. Tap a slot and type to replace its character, drag one slot onto
/// another to swap them, or use Swap to trade with a slot on a different key.
private struct LayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLayer: LayoutEditorLayer = .letters
    @State private var layout = EditableKeyboardLayout.savedOrDefault
    @State private var focusedRow = 1
    @State private var focusedCol = 1
    @State private var selectedPosition: KeyCellPosition?
    @State private var swapSource: LayoutCellReference?
    @State private var draft = ""
    @State private var history: [EditableKeyboardLayout] = []
    @State private var isConfirmingRestore = false
    @FocusState private var isTyping: Bool

    let theme: KeyboardTheme
    let onLayoutChanged: () -> Void

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Layer", selection: $selectedLayer) {
                        ForEach(LayoutEditorLayer.allCases) { layer in
                            Text(layer.title).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)

                    miniMap

                    Text(swapSource == nil ? "Tap a key to zoom in" : "Pick any key, then the slot to swap with")
                        .font(.footnote)
                        .foregroundStyle(swapSource == nil ? Color.secondary : Color.accentColor)

                    FocusKeyView(
                        layer: selectedLayer,
                        row: focusedRow,
                        col: focusedCol,
                        key: key(atRow: focusedRow, col: focusedCol),
                        theme: theme,
                        selectedPosition: selectedPosition,
                        swapSource: swapSource,
                        onTap: tapSlot,
                        onDropCell: moveCell
                    )
                    .frame(maxWidth: 440)

                    inspector
                        .id("inspector")
                }
                .padding()
            }
            .onChange(of: selectedPosition) { _ in
                withAnimation { proxy.scrollTo("inspector", anchor: .bottom) }
            }
            .onChange(of: isTyping) { typing in
                guard typing else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation { proxy.scrollTo("inspector", anchor: .bottom) }
                }
            }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onDisappear(perform: saveIfChanged)
            .onChange(of: selectedLayer) { _ in
                selectedPosition = nil
                swapSource = nil
                isTyping = false
            }
            .onChange(of: draft) { newValue in
                applyDraft(newValue)
            }
            .navigationTitle("Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(history.isEmpty)
                    .accessibilityLabel("Undo")

                    Button("Restore") {
                        isConfirmingRestore = true
                    }
                    .confirmationDialog("Restore the default layout?", isPresented: $isConfirmingRestore, titleVisibility: .visible) {
                        Button("Restore Default Layout", role: .destructive) {
                            recordHistory()
                            layout = .default
                            KeyboardLayoutData.restoreDefaultEditableLayout()
                            selectedPosition = nil
                            swapSource = nil
                            onLayoutChanged()
                        }
                    } message: {
                        Text("This replaces every change you made. You can undo it until you close the editor.")
                    }
                }
            }
        }
    }

    // MARK: Mini map

    private var miniMap: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        let isFocused = row == focusedRow && col == focusedCol
                        MiniKeyView(key: key(atRow: row, col: col), theme: theme)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.accentColor, lineWidth: isFocused ? 3 : 0)
                                        .padding(-4)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    focusedRow = row
                                    focusedCol = col
                                    if swapSource == nil {
                                        selectedPosition = nil
                                        isTyping = false
                                    }
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel("Key \(key(atRow: row, col: col).value(at: .center))")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Inspector

    @ViewBuilder
    private var inspector: some View {
        if let swapSource {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3.weight(.semibold))
                Text("Swapping \(Text(value(for: swapSource)).bold()). Tap the slot to trade with.")
                    .font(.callout)
                Spacer(minLength: 0)
                Button("Cancel") { self.swapSource = nil }
            }
            .padding(14)
            .background(cardBackground)
        } else if let position = selectedPosition {
            let reference = currentReference(position)
            HStack(spacing: 12) {
                Image(systemName: Self.symbol(for: position))
                    .font(.title2.weight(.semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.gestureName(for: position))
                        .font(.callout.weight(.semibold))
                    Text("on \(key(atRow: focusedRow, col: focusedCol).value(at: .center))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                TextField(value(for: reference).isEmpty ? "–" : value(for: reference), text: $draft)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($isTyping)
                    .submitLabel(.done)
                    .onSubmit { isTyping = false }
                    .frame(width: 56, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )

                Menu {
                    Button {
                        swapSource = reference
                        isTyping = false
                    } label: {
                        Label("Swap with another slot", systemImage: "arrow.left.arrow.right")
                    }
                    if position != .center {
                        Button(role: .destructive) {
                            recordHistory()
                            setValue("", for: reference)
                            draft = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(14)
            .background(cardBackground)

            Text("Type to replace · drag between slots to swap")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Tap a slot to change it, or drag one slot onto another to swap them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    // MARK: Actions

    private func tapSlot(_ position: KeyCellPosition) {
        let target = currentReference(position)
        if let source = swapSource {
            swap(source, target)
            swapSource = nil
            selectedPosition = position
            draft = ""
            return
        }
        selectedPosition = position
        draft = ""
    }

    /// Each keystroke replaces the slot with the last character typed, so the
    /// field never has to be cleared first.
    private func applyDraft(_ newValue: String) {
        guard let position = selectedPosition, let last = newValue.last else { return }
        let character = String(last)
        if newValue != character {
            draft = character
            return
        }
        guard character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        let reference = currentReference(position)
        guard value(for: reference) != character else { return }
        recordHistory()
        setValue(character, for: reference)
    }

    private func currentReference(_ position: KeyCellPosition) -> LayoutCellReference {
        LayoutCellReference(layer: selectedLayer, row: focusedRow, col: focusedCol, position: position)
    }

    /// Leaving the editor keeps the edits. Before, only Save stored them, so
    /// Done or swiping the sheet away silently threw every move away.
    private func saveIfChanged() {
        guard layout != EditableKeyboardLayout.savedOrDefault else { return }
        KeyboardLayoutData.saveEditableLayout(layout)
        onLayoutChanged()
    }

    private func key(atRow row: Int, col: Int) -> EditableKeyConfig {
        grid(for: selectedLayer)[row][col]
    }

    private func grid(for layer: LayoutEditorLayer) -> [[EditableKeyConfig]] {
        switch layer {
        case .letters:
            return layout.letterGrid
        case .symbols:
            return layout.symbolOverlayGrid
        case .numbers:
            return layout.numberGrid
        }
    }

    private func value(for reference: LayoutCellReference) -> String {
        guard reference.row >= 0, reference.row < 3, reference.col >= 0, reference.col < 3 else {
            return ""
        }
        return grid(for: reference.layer)[reference.row][reference.col].value(at: reference.position)
    }

    private func moveCell(payload: String, position: KeyCellPosition) {
        guard let source = LayoutCellReference(payload: payload) else { return }
        swap(source, currentReference(position))
        selectedPosition = position
    }

    private func swap(_ source: LayoutCellReference, _ target: LayoutCellReference) {
        guard source.payload != target.payload else { return }
        let sourceValue = value(for: source)
        let targetValue = value(for: target)
        guard !sourceValue.isEmpty || !targetValue.isEmpty else { return }
        // A tap character can't be left empty, so refuse a swap that would empty one.
        if (source.position == .center && targetValue.isEmpty) || (target.position == .center && sourceValue.isEmpty) {
            return
        }
        recordHistory()
        setValue(sourceValue, for: target)
        setValue(targetValue, for: source)
    }

    private func recordHistory() {
        history.append(layout)
        if history.count > 50 { history.removeFirst() }
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        layout = previous
        swapSource = nil
        draft = ""
    }

    private func setValue(_ value: String, for reference: LayoutCellReference) {
        guard reference.row >= 0, reference.row < 3, reference.col >= 0, reference.col < 3 else { return }

        switch reference.layer {
        case .letters:
            layout.letterGrid[reference.row][reference.col].setValue(value, at: reference.position)
        case .symbols:
            layout.symbolOverlayGrid[reference.row][reference.col].setValue(value, at: reference.position)
        case .numbers:
            layout.numberGrid[reference.row][reference.col].setValue(value, at: reference.position)
        }
    }

    // MARK: Labels

    static func symbol(for position: KeyCellPosition) -> String {
        switch position {
        case .topLeft: return "arrow.up.left"
        case .top: return "arrow.up"
        case .topRight: return "arrow.up.right"
        case .left: return "arrow.left"
        case .center: return "hand.tap"
        case .right: return "arrow.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottom: return "arrow.down"
        case .bottomRight: return "arrow.down.right"
        }
    }

    static func gestureName(for position: KeyCellPosition) -> String {
        switch position {
        case .topLeft: return "Swipe up-left"
        case .top: return "Swipe up"
        case .topRight: return "Swipe up-right"
        case .left: return "Swipe left"
        case .center: return "Tap"
        case .right: return "Swipe right"
        case .bottomLeft: return "Swipe down-left"
        case .bottom: return "Swipe down"
        case .bottomRight: return "Swipe down-right"
        }
    }
}

private let keyCellRows: [[KeyCellPosition]] = [
    [.topLeft, .top, .topRight],
    [.left, .center, .right],
    [.bottomLeft, .bottom, .bottomRight],
]

private struct KeyBackground: View {
    let theme: KeyboardTheme
    let cornerRadius: CGFloat

    var body: some View {
        OctagonalKeyShape(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [theme.keyGradientTop ?? theme.keyBackground, theme.keyGradientBottom ?? theme.keyBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                OctagonalKeyShape(cornerRadius: cornerRadius)
                    .stroke(theme.keyBorder, lineWidth: 1)
            )
    }
}

/// A small read-only key for the mini map.
private struct MiniKeyView: View {
    let key: EditableKeyConfig
    let theme: KeyboardTheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(keyCellRows[row], id: \.self) { position in
                        Text(key.value(at: position))
                            .font(.system(size: position == .center ? 20 : 8, weight: .bold, design: .rounded))
                            .foregroundStyle(position == .center ? theme.tapColor : theme.swipeColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(3)
        .background(KeyBackground(theme: theme, cornerRadius: 8))
    }
}

/// The focused key, drawn as large as the screen allows. Every slot is a
/// separate view in a plain grid, so each one owns its own hit area.
private struct FocusKeyView: View {
    let layer: LayoutEditorLayer
    let row: Int
    let col: Int
    let key: EditableKeyConfig
    let theme: KeyboardTheme
    let selectedPosition: KeyCellPosition?
    let swapSource: LayoutCellReference?
    let onTap: (KeyCellPosition) -> Void
    let onDropCell: (String, KeyCellPosition) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width / 3
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(keyCellRows[r], id: \.self) { position in
                            slot(position, side: side)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(10)
        // A rounded square rather than the keyboard's octagon: the corner
        // slots are full squares, and an octagon cut through them.
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.keyGradientTop ?? theme.keyBackground, theme.keyGradientBottom ?? theme.keyBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.keyBorder, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func slot(_ position: KeyCellPosition, side: CGFloat) -> some View {
        let value = key.value(at: position)
        let reference = LayoutCellReference(layer: layer, row: row, col: col, position: position)
        let isSelected = selectedPosition == position && swapSource == nil
        let isSwapSource = swapSource?.payload == reference.payload
        let isCenter = position == .center

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCenter ? theme.activeKeyBackground.opacity(0.38) : theme.swipeColor.opacity(0.06))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSwapSource ? Color.orange : Color.accentColor, lineWidth: isSelected || isSwapSource ? 3 : 0)
            if swapSource != nil && !isSwapSource {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }

            Text(value)
                .font(.system(size: isCenter ? side * 0.56 : side * 0.38, weight: isCenter ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isCenter ? theme.tapColor : theme.swipeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            if !isCenter {
                Image(systemName: LayoutEditorView.symbol(for: position))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.swipeColor.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: arrowAlignment(position))
                    .padding(7)
            }
        }
        .padding(3)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .onTapGesture { onTap(position) }
        .onDrag {
            NSItemProvider(object: reference.payload as NSString)
        } preview: {
            Text(value.isEmpty ? " " : value)
                .font(.largeTitle.bold())
                .foregroundStyle(isCenter ? theme.tapColor : theme.swipeColor)
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .onDrop(of: [UTType.plainText], delegate: LayoutCellDropDelegate(position: position, onDropCell: onDropCell))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(LayoutEditorView.gestureName(for: position)): \(value.isEmpty ? "empty" : value)")
        .accessibilityAddTraits(.isButton)
    }

    private func arrowAlignment(_ position: KeyCellPosition) -> Alignment {
        switch position {
        case .topLeft: return .topLeading
        case .top: return .top
        case .topRight: return .topTrailing
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .bottomLeft: return .bottomLeading
        case .bottom: return .bottom
        case .bottomRight: return .bottomTrailing
        }
    }
}

private struct LayoutCellDropDelegate: DropDelegate {
    let position: KeyCellPosition
    let onDropCell: (String, KeyCellPosition) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let payload: String?
            if let data = item as? Data {
                payload = String(data: data, encoding: .utf8)
            } else if let string = item as? String {
                payload = string
            } else if let nsString = item as? NSString {
                payload = nsString as String
            } else {
                payload = nil
            }

            guard let payload else { return }
            DispatchQueue.main.async {
                onDropCell(payload, position)
            }
        }

        return true
    }
}
