import SpectrogramCore
import SwiftUI

struct DisplaySettingsView: View {
    @ObservedObject var session: SpectrogramSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Frequency range") {
                    Picker("Minimum", selection: minimum) {
                        ForEach([20.0, 32, 50, 100, 200, 500, 1_000], id: \.self) { frequency in
                            Text(FrequencyScale.label(for: frequency, precise: true)).tag(frequency)
                        }
                    }
                    .accessibilityIdentifier("minimum-frequency")
                    Picker("Maximum", selection: maximum) {
                        ForEach([1_000.0, 2_000, 4_000, 8_000, 12_000, 16_000, 20_000, 24_000]
                            .filter { $0 >= session.frequencyRange.minimum * 2 }, id: \.self) { frequency in
                            Text(FrequencyScale.label(for: frequency, precise: true)).tag(frequency)
                        }
                    }
                    .accessibilityIdentifier("maximum-frequency")
                    Text("The upper limit follows the microphone’s supported frequency range.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Contrast") {
                    LabeledContent("Noise floor", value: "\(Int(session.displayFloor)) dBFS")
                    Slider(value: $session.displayFloor, in: -120 ... -60, step: 5)
                        .accessibilityLabel("Display noise floor")
                    LabeledContent("Contrast", value: String(format: "%.2f×", session.contrast))
                    Slider(value: $session.contrast, in: 0.75 ... 2, step: 0.05)
                        .accessibilityLabel("Spectrogram contrast")
                    Text("Raise the noise floor or contrast to darken background noise. Peak measurements remain unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Restore defaults") {
                    session.frequencyRange = .standard
                    session.displayFloor = -90
                    session.contrast = 1.35
                }
            }
            .navigationTitle("Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("close-display-settings")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var minimum: Binding<Double> {
        Binding(get: { session.frequencyRange.minimum }, set: {
            session.frequencyRange = FrequencyRange(minimum: $0, maximum: session.frequencyRange.maximum)
        })
    }
    private var maximum: Binding<Double> {
        Binding(get: { session.frequencyRange.maximum }, set: {
            session.frequencyRange = FrequencyRange(minimum: session.frequencyRange.minimum, maximum: $0)
        })
    }
}
