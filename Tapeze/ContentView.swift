import SwiftUI

struct ContentView: View {
    @AppStorage(KeyboardState.showGestureTrailDefaultsKey, store: KeyboardState.settingsDefaults) private var showGestureTrail = true
    @AppStorage(KeyboardState.selectedThemeDefaultsKey, store: KeyboardState.settingsDefaults) private var selectedThemeID = KeyboardTheme.classic.id
    @State private var testText: String = ""
    @StateObject private var previewState = KeyboardState()

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
            previewState.showGestureTrail = showGestureTrail
            previewState.selectedThemeID = selectedThemeID
        }
        .onChange(of: showGestureTrail) { newValue in
            previewState.showGestureTrail = newValue
        }
        .onChange(of: selectedThemeID) { newValue in
            previewState.selectedThemeID = newValue
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tapeze")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Gesture keyboard setup, themes, and preview.")
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

                Text("A non-functional preview using the selected theme.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            KeyboardView(
                state: previewState,
                onCharacter: { char in testText += char },
                onBackspace: {
                    if !testText.isEmpty { testText.removeLast() }
                },
                onEnter: { testText += "\n" },
                onNextKeyboard: nil
            )
            .frame(height: previewState.keyboardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            TextField("Type here to test...", text: $testText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var setupInstructionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Instructions")
                .font(.headline)

            instructionRow(number: 1, text: "Open Settings → General → Keyboard → Keyboards")
            instructionRow(number: 2, text: "Tap \"Add New Keyboard...\"")
            instructionRow(number: 3, text: "Select \"Tapeze\"")
            instructionRow(number: 4, text: "Open Notes or the test field below")
            instructionRow(number: 5, text: "Long-press 🌐 and select \"Tapeze\"")

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
            HStack(alignment: .firstTextBaseline) {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Text(KeyboardTheme.theme(for: selectedThemeID).name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(KeyboardTheme.all) { theme in
                            Button {
                                selectedThemeID = theme.id
                            } label: {
                                ThemeSwatch(theme: theme, isSelected: selectedThemeID == theme.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Toggle("Show gesture trail", isOn: $showGestureTrail)
                .font(.subheadline)
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

private struct ThemeSwatch: View {
    let theme: KeyboardTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isSelected ? theme.tapColor : Color(.separator).opacity(0.45), lineWidth: isSelected ? 2 : 1)
                    )

                Circle()
                    .fill(theme.tapColor)
                    .frame(width: 16, height: 16)
                    .offset(x: -15, y: -8)

                Circle()
                    .fill(theme.swipeColor)
                    .frame(width: 10, height: 10)
                    .offset(x: 16, y: 9)
            }
            .frame(width: 64, height: 44)

            Text(theme.name)
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 72, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color(.tertiarySystemGroupedBackground) : Color.clear)
        )
    }
}
