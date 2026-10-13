import SpectrogramCore
import SwiftUI

struct SpectrogramPane: View {
    @ObservedObject var session: SpectrogramSession

    private var range: FrequencyRange {
        session.frequencyRange.limited(to: session.history.latest()?.nyquistFrequency ?? 24_000)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MetalSpectrogramView(
                    history: session.history,
                    capturePaused: !session.phase.isCapturing,
                    scrollClock: session.scrollClock,
                    frequencyRange: range,
                    displayFloor: session.displayFloor,
                    contrast: session.contrast
                )

                if let selection = session.selection {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.95))
                        .frame(height: 1)
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
            .accessibilityHint("Newest audio is at the top. Tap vertically to inspect the spectrum at that time")
            .accessibilityAction(named: "Inspect newest slice") {
                session.selectSlice(normalizedYFromTop: 0)
            }
            .accessibilityIdentifier("spectrogram-waterfall")
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
