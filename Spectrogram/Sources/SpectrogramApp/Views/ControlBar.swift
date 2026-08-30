import SpectrogramCore
import SwiftUI

struct ControlBar: View {
    @ObservedObject var session: SpectrogramSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(session.phase.statusText)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)

                if let peak = session.latestPeak, session.selection == nil {
                    Text("Peak \(FrequencyScale.label(for: peak.frequency, precise: true))")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else {
                    Text("Spectrogram")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }

            Spacer(minLength: 8)

            Button {
                session.clearHistory()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(session.framesCaptured == 0)
            .accessibilityLabel("Clear spectrogram")

            Button {
                session.toggleCapture()
            } label: {
                Image(systemName: session.phase.isCapturing ? "pause.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.primary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)
            .accessibilityLabel(session.phase.isCapturing ? "Pause" : "Resume")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canToggle: Bool {
        switch session.phase {
        case .running, .paused, .interrupted, .idle:
            return true
        case .requestingPermission, .permissionDenied, .failed:
            return false
        }
    }

    private var statusColor: Color {
        switch session.phase {
        case .running:
            return .green
        case .paused, .interrupted:
            return .orange
        case .failed, .permissionDenied:
            return .red
        case .idle, .requestingPermission:
            return .secondary
        }
    }
}
