import SwiftUI

struct ContentView: View {
    @AppStorage(KeyboardState.showGestureTrailDefaultsKey) private var showGestureTrail = true
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
            .onAppear {
                previewState.showGestureTrail = showGestureTrail
            }
            .onChange(of: showGestureTrail) { newValue in
                previewState.showGestureTrail = newValue
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
        Toggle("Show gesture trail", isOn: $showGestureTrail)
            .font(.subheadline)
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
