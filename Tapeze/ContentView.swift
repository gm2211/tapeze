import SwiftUI

struct ContentView: View {
    @AppStorage(KeyboardState.showGestureTrailDefaultsKey, store: KeyboardState.settingsDefaults) private var showGestureTrail = true
    @AppStorage(KeyboardState.selectedThemeDefaultsKey, store: KeyboardState.settingsDefaults) private var selectedThemeID = KeyboardTheme.classic.id
    @State private var testText: String = ""
    @StateObject private var previewState = KeyboardState()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Tapeze Keyboard")
                    .font(.largeTitle.bold())
                    .padding(.top, 30)

                Text("A gesture-based keyboard inspired by MessagEase")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                setupInstructionsView

                settingsView

                Divider()

                // Preview area
                Text("Keyboard Preview")
                    .font(.headline)

                Text("The keyboard below is a non-functional preview.\nTo use the real keyboard, enable it in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

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
                .padding(.horizontal, 8)

                // Test text field
                TextField("Type here to test...", text: $testText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(previewState.theme.keyboardBackground.opacity(0.08))
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }

            Picker("Theme", selection: $selectedThemeID) {
                ForEach(KeyboardTheme.all) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                ForEach(KeyboardTheme.all) { theme in
                    Button {
                        selectedThemeID = theme.id
                    } label: {
                        ThemeSwatch(theme: theme, isSelected: selectedThemeID == theme.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle("Show gesture trail", isOn: $showGestureTrail)
                .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.bold)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ThemeSwatch: View {
    let theme: KeyboardTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? theme.tapColor : theme.keyBorder, lineWidth: isSelected ? 2 : 1)
                    )

                Circle()
                    .fill(theme.tapColor)
                    .frame(width: 12, height: 12)
                    .offset(x: -8, y: -4)

                Circle()
                    .fill(theme.swipeColor)
                    .frame(width: 8, height: 8)
                    .offset(x: 9, y: 7)
            }
            .frame(width: 44, height: 34)

            Text(theme.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: 54)
        }
    }
}
