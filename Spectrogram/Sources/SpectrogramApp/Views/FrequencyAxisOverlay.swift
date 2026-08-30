import SpectrogramCore
import SwiftUI

struct FrequencyAxisOverlay: View {
    let maximumFrequency: Double

    var body: some View {
        GeometryReader { geometry in
            let ticks = FrequencyScale.ticks(maximum: maximumFrequency)
            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { frequency in
                    let normalized = FrequencyScale.normalizedPosition(
                        for: frequency,
                        maximum: maximumFrequency
                    )
                    let x = normalized * geometry.size.width

                    Rectangle()
                        .fill(.white.opacity(frequency == 1_000 ? 0.22 : 0.12))
                        .frame(width: 0.5, height: geometry.size.height)
                        .position(x: x, y: geometry.size.height / 2)

                    Text(FrequencyScale.label(for: frequency))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .shadow(color: .black, radius: 2)
                        .frame(width: 42)
                        .position(
                            x: min(max(x, 21), geometry.size.width - 21),
                            y: geometry.size.height - 10
                        )
                }

                VStack {
                    Text("older")
                    Spacer()
                    Text("now")
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.vertical, 7)
                .padding(.leading, 6)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
