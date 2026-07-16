import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(KeyboardState.showGestureTrailDefaultsKey, store: KeyboardState.settingsDefaults) private var showGestureTrail = true
    @AppStorage(KeyboardState.keyCornerRadiusDefaultsKey, store: KeyboardState.settingsDefaults) private var keyCornerRadius = Double(KeyboardState.defaultKeyCornerRadius)
    @AppStorage(KeyboardState.themeDefaultsKey, store: KeyboardState.settingsDefaults) private var selectedThemeID = KeyboardTheme.tapeze.id
    @State private var testText: String = ""
    @State private var isLayoutEditorPresented = false
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
            instructionRow(number: 4, text: "Open Notes or the test field below")
            instructionRow(number: 5, text: "Long-press 🌐 and select \"tapeze\"")

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

private struct LayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLayer: LayoutEditorLayer = .letters
    @State private var layout = EditableKeyboardLayout.savedOrDefault
    @State private var savedMarker = false

    let theme: KeyboardTheme
    let onLayoutChanged: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Layer", selection: $selectedLayer) {
                    ForEach(LayoutEditorLayer.allCases) { layer in
                        Text(layer.title).tag(layer)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { col in
                                EditableKeyTile(
                                    layer: selectedLayer,
                                    row: row,
                                    col: col,
                                    key: key(atRow: row, col: col),
                                    theme: theme,
                                    onDropCell: moveCell
                                )
                            }
                        }
                    }
                }
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Restore") {
                        layout = .default
                        KeyboardLayoutData.restoreDefaultEditableLayout()
                        savedMarker.toggle()
                        onLayoutChanged()
                    }

                    Button("Save") {
                        KeyboardLayoutData.saveEditableLayout(layout)
                        savedMarker.toggle()
                        onLayoutChanged()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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

    private func moveCell(payload: String, toRow row: Int, col: Int, position: KeyCellPosition) {
        guard let source = LayoutCellReference(payload: payload) else { return }
        let target = LayoutCellReference(layer: selectedLayer, row: row, col: col, position: position)
        guard source.payload != target.payload else { return }

        let sourceValue = value(for: source)
        guard !sourceValue.isEmpty else { return }

        let targetValue = value(for: target)
        setValue(sourceValue, for: target)
        setValue(targetValue, for: source)
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
}

private struct EditableKeyTile: View {
    let layer: LayoutEditorLayer
    let row: Int
    let col: Int
    let key: EditableKeyConfig
    let theme: KeyboardTheme
    let onDropCell: (String, Int, Int, KeyCellPosition) -> Void

    var body: some View {
        GeometryReader { geo in
            let cellSide = geo.size.width / 3

            ZStack {
                ForEach(Array(KeyCellPosition.allCases), id: \.self) { position in
                    let value = key.value(at: position)
                    let reference = LayoutCellReference(layer: layer, row: row, col: col, position: position)

                    Text(value)
                        .font(.system(size: position == .center ? cellSide * 0.56 : cellSide * 0.34, weight: position == .center ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(position == .center ? theme.tapColor : theme.swipeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(width: cellSide, height: cellSide)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(position == .center ? theme.activeKeyBackground.opacity(0.38) : Color.white.opacity(0.055))
                        )
                        .position(cellCenter(for: position, cellSide: cellSide))
                        .onDrag {
                            NSItemProvider(object: reference.payload as NSString)
                        } preview: {
                            Text(value.isEmpty ? " " : value)
                                .font(.title2.bold())
                                .foregroundStyle(position == .center ? theme.tapColor : theme.swipeColor)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: LayoutCellDropDelegate(
                                row: row,
                                col: col,
                                position: position,
                                onDropCell: onDropCell
                            )
                        )
                }
            }
        }
        .padding(5)
        .background(
            OctagonalKeyShape(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [theme.keyGradientTop ?? theme.keyBackground, theme.keyGradientBottom ?? theme.keyBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    OctagonalKeyShape(cornerRadius: 8)
                        .stroke(theme.keyBorder, lineWidth: 1)
                )
        )
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellCenter(for position: KeyCellPosition, cellSide: CGFloat) -> CGPoint {
        let index = KeyCellPosition.allCases.firstIndex(of: position) ?? 0
        let row = index / 3
        let col = index % 3
        return CGPoint(
            x: CGFloat(col) * cellSide + cellSide / 2,
            y: CGFloat(row) * cellSide + cellSide / 2
        )
    }
}

private struct LayoutCellDropDelegate: DropDelegate {
    let row: Int
    let col: Int
    let position: KeyCellPosition
    let onDropCell: (String, Int, Int, KeyCellPosition) -> Void

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
                onDropCell(payload, row, col, position)
            }
        }

        return true
    }
}
