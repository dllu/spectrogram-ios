import Foundation

enum CapturePhase: Equatable {
    case idle
    case requestingPermission
    case running
    case paused
    case interrupted
    case permissionDenied
    case failed(String)

    var isCapturing: Bool {
        self == .running
    }

    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .requestingPermission:
            return "Waiting for microphone access"
        case .running:
            return "Listening"
        case .paused:
            return "Paused"
        case .interrupted:
            return "Audio interrupted"
        case .permissionDenied:
            return "Microphone access is off"
        case let .failed(message):
            return message
        }
    }
}
