import SwiftUI

/// What the keyboard shows while dictating.
final class DictationOverlayModel: ObservableObject {
    @Published var isVisible = false
    @Published var transcript = ""
    /// Recent input levels, oldest first, for the waveform.
    @Published var levels: [CGFloat] = Array(repeating: 0, count: DictationOverlayModel.barCount)
    @Published var isWaitingForMic = false

    static let barCount = 21

    func push(level: Float) {
        levels.removeFirst()
        levels.append(CGFloat(level))
    }

    func reset() {
        transcript = ""
        levels = Array(repeating: 0, count: Self.barCount)
        isWaitingForMic = false
    }
}

/// Dims the keyboard in place and shows a live waveform, the words so far, and
/// discard / done buttons. Tapping anywhere else also finishes, so the next
/// tap gets you straight back to typing.
struct DictationOverlayView: View {
    @ObservedObject var model: DictationOverlayModel
    @ObservedObject var state: KeyboardState
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 220
            ZStack {
                state.theme.keyboardBackground.opacity(0.82)
                    .background(.ultraThinMaterial)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDone)

                VStack(spacing: compact ? 8 : 14) {
                    Waveform(levels: model.levels, color: state.theme.specialTextColor)
                        .frame(height: compact ? 30 : 46)

                    Text(caption)
                        .font(.system(size: compact ? 15 : 17))
                        .foregroundColor(model.transcript.isEmpty ? .secondary : state.theme.specialTextColor)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .allowsHitTesting(false)

                    HStack(spacing: compact ? 28 : 40) {
                        RoundButton(
                            systemName: "xmark",
                            label: "discard",
                            fill: state.theme.commandBackground,
                            foreground: state.theme.specialTextColor.opacity(0.85),
                            diameter: compact ? 44 : 56,
                            action: onCancel
                        )
                        RoundButton(
                            systemName: "stop.fill",
                            label: "done",
                            fill: state.theme.specialTextColor,
                            foreground: state.theme.keyboardBackground,
                            diameter: compact ? 44 : 56,
                            action: onDone
                        )
                    }
                }
            }
        }
    }

    private var caption: String {
        if model.isWaitingForMic { return "Starting the mic…" }
        return model.transcript.isEmpty ? "Listening…" : model.transcript
    }
}

private struct Waveform: View {
    let levels: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(levels.count)
            let barWidth = min(5, geo.size.width / (count * 2))
            HStack(alignment: .center, spacing: barWidth) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    // Taper the ends so it reads as a wave, not a bar chart.
                    let position = CGFloat(index) / max(count - 1, 1)
                    let taper = 0.35 + 0.65 * sin(position * .pi)
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: max(barWidth, geo.size.height * level * taper))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.linear(duration: 0.08), value: levels)
        }
        .allowsHitTesting(false)
    }
}

private struct RoundButton: View {
    let systemName: String
    let label: String
    let fill: Color
    let foreground: Color
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.36, weight: .semibold))
                .foregroundColor(foreground)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
