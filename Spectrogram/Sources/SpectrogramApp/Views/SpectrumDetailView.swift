import SpectrogramCore
import SwiftUI

struct SpectrumDetailView: View {
    @ObservedObject var session: SpectrogramSession
    let selection: SpectrumSelection

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INTENSITY × FREQUENCY")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(session.ageDescription(for: selection.frame))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let peak = selection.peak {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(FrequencyScale.label(for: peak.frequency, precise: true))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.cyan)
                            .monospacedDigit()
                        Text(String(format: "%.1f dBFS", peak.magnitudeDB))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    session.dismissSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close spectrum detail")
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)

            SpectrumPlotView(selection: selection) { normalizedX in
                session.selectPeak(normalizedX: normalizedX)
            }
            .frame(minHeight: 170)

            Text("Tap the trace to snap to the nearest peak")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 7)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }
}
