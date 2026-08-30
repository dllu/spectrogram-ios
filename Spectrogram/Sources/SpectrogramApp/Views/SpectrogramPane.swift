import SpectrogramCore
import SwiftUI

struct SpectrogramPane: View {
    @ObservedObject var session: SpectrogramSession

    private var maximumFrequency: Double {
        guard let frame = session.history.latest() else {
            return FrequencyScale.defaultMaximum
        }
        return FrequencyScale.displayMaximum(nyquist: frame.nyquistFrequency)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MetalSpectrogramView(history: session.history)
                FrequencyAxisOverlay(maximumFrequency: maximumFrequency)

                if let selection = session.selection {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.95))
                        .frame(height: 1)
                        .shadow(color: .cyan, radius: 2)
                        .position(
                            x: geometry.size.width / 2,
                            y: selection.tappedNormalizedY * geometry.size.height
                        )
                        .allowsHitTesting(false)
                }

                if session.framesCaptured == 0 {
                    CaptureStatusOverlay(phase: session.phase)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    guard geometry.size.height > 0 else { return }
                    session.selectSlice(
                        normalizedYFromTop: value.location.y / geometry.size.height
                    )
                }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live spectrogram")
            .accessibilityHint("Tap vertically to inspect the spectrum at that time")
        }
        .clipped()
    }
}

private struct CaptureStatusOverlay: View {
    let phase: CapturePhase

    var body: some View {
        VStack(spacing: 10) {
            switch phase {
            case .requestingPermission:
                ProgressView()
                    .tint(.white)
            case .permissionDenied:
                Image(systemName: "mic.slash.fill")
                    .font(.title2)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
            default:
                Image(systemName: "waveform")
                    .font(.title2)
            }

            Text(phase.statusText)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(18)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
    }
}
