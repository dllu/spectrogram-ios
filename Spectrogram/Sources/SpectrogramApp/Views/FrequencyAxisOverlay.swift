import SpectrogramCore
import SwiftUI

/// A separate ruler above the waterfall. Its coordinates match the Metal
/// frequency mapping exactly, without covering the newest spectrum rows.
struct FrequencyAxisOverlay: View {
    let minimumFrequency: Double
    let maximumFrequency: Double

    var body: some View {
        GeometryReader { geometry in
            let majorTicks = FrequencyScale.octaveTicks(minimum: minimumFrequency, maximum: maximumFrequency)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.white.opacity(0.14))
                    .frame(height: 0.5)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 0.5)

                ForEach(FrequencyScale.halfOctaveTicks(minimum: minimumFrequency, maximum: maximumFrequency), id: \.self) { frequency in
                    Rectangle().fill(.white.opacity(0.3))
                        .frame(width: 0.5, height: 3)
                        .position(x: x(frequency, width: geometry.size.width), y: geometry.size.height - 1.5)
                }
                ForEach(majorTicks, id: \.self) { frequency in
                    let position = x(frequency, width: geometry.size.width)
                    Rectangle().fill(.white.opacity(0.65))
                        .frame(width: 1, height: 7)
                        .position(x: position, y: geometry.size.height - 3.5)
                    Text(FrequencyScale.label(for: frequency))
                        .font(.system(size: geometry.size.width < 360 ? 9 : 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize()
                        .position(x: min(max(position, 17), geometry.size.width - 17), y: 9)
                }
            }
        }
        .frame(height: 27)
        .background(Color(uiColor: .secondarySystemBackground))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Frequency axis, major ticks every octave")
        .accessibilityValue("\(FrequencyScale.label(for: minimumFrequency, precise: true)) to \(FrequencyScale.label(for: maximumFrequency, precise: true))")
        .accessibilityIdentifier("waterfall-frequency-axis")
    }

    private func x(_ frequency: Double, width: CGFloat) -> CGFloat {
        CGFloat(FrequencyScale.normalizedPosition(for: frequency, minimum: minimumFrequency, maximum: maximumFrequency)) * width
    }
}
