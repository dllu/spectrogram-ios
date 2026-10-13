import AVFoundation
import Combine
import Foundation
import SpectrogramCore

@MainActor
final class SpectrogramSession: ObservableObject {
    static let historyCapacity = 1_024

    let history = SpectrogramHistory(capacity: historyCapacity)

    @Published private(set) var phase: CapturePhase = .idle
    @Published private(set) var latestPeak: SpectrumPeak?
    @Published private(set) var framesCaptured = 0
    @Published var selection: SpectrumSelection?

    private let analyzer = SpectrumAnalyzer()
    private let isUITesting: Bool
    private var notificationTokens: [NSObjectProtocol] = []
    private var wasRunningBeforeInterruption = false
    private var shouldResumeWhenActive = false
    private var isSceneActive = true
    private var isRestartingForRouteChange = false

    init() {
#if DEBUG
        isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
#else
        isUITesting = false
#endif
        let history = self.history
        analyzer.onFrame = { [weak self, history] frame, shouldPublish in
            let generation = history.generation
            let storedFrame = history.append(frame)
            guard shouldPublish else { return }
            let peak = PeakDetector.strongestPeak(
                in: storedFrame,
                maximumFrequency: FrequencyScale.displayMaximum(nyquist: storedFrame.nyquistFrequency)
            )
            DispatchQueue.main.async { [weak self] in
                guard let self, self.phase.isCapturing,
                      history.generation == generation else { return }
                self.latestPeak = peak
                self.framesCaptured = history.count
            }
        }

        if !isUITesting {
            observeAudioEvents()
        }
    }

    deinit {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func startIfNeeded() {
        guard phase == .idle || phase == .permissionDenied else { return }

        if isUITesting {
            loadUITestHistory()
            phase = .paused
            return
        }

        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            startCapture()
        case .denied:
            phase = .permissionDenied
        case .undetermined:
            phase = .requestingPermission
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.startCapture()
                    } else {
                        self.phase = .permissionDenied
                    }
                }
            }
        @unknown default:
            phase = .permissionDenied
        }
    }

    func toggleCapture() {
        if phase.isCapturing {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        guard phase == .running else { return }
        if !isUITesting {
            analyzer.pause()
        }
        phase = .paused
        framesCaptured = history.count
        if let frame = history.latest() {
            latestPeak = PeakDetector.strongestPeak(
                in: frame,
                maximumFrequency: FrequencyScale.displayMaximum(nyquist: frame.nyquistFrequency)
            )
        }
    }

    func resume() {
        switch phase {
        case .paused, .interrupted, .idle, .failed:
            break
        case .requestingPermission, .running, .permissionDenied:
            return
        }
        selection = nil
        if isUITesting {
            phase = .running
            return
        }
        startCapture()
    }

    func selectSlice(normalizedYFromTop y: Double) {
        if phase == .running {
            pause()
        }
        let clampedY = min(max(y, 0), 1)
        guard let frame = history.frame(normalizedYFromTop: clampedY) else { return }

        let maximum = FrequencyScale.displayMaximum(nyquist: frame.nyquistFrequency)
        selection = SpectrumSelection(
            frame: frame,
            peak: PeakDetector.strongestPeak(in: frame, maximumFrequency: maximum),
            tappedNormalizedY: clampedY
        )
    }

    func selectPeak(normalizedX: Double) {
        guard var selection else { return }
        let maximum = FrequencyScale.displayMaximum(nyquist: selection.frame.nyquistFrequency)
        let frequency = FrequencyScale.frequency(at: normalizedX, maximum: maximum)
        let peak = PeakDetector.nearestPeak(
            to: frequency,
            in: selection.frame,
            maximumFrequency: maximum
        )
        guard peak != selection.peak else { return }
        selection.peak = peak
        self.selection = selection
    }

    func dismissSelection() {
        selection = nil
    }

    func clearHistory() {
        history.clear()
        framesCaptured = 0
        latestPeak = nil
        selection = nil
    }

    func handleSceneActive(_ isActive: Bool) {
        isSceneActive = isActive
        if !isActive, phase == .running {
            shouldResumeWhenActive = true
            pause()
        } else if isActive, phase == .permissionDenied {
            // The user may have granted access in Settings while the app was inactive.
            startIfNeeded()
        } else if isActive, shouldResumeWhenActive {
            shouldResumeWhenActive = false
            resume()
        }
    }

    func ageDescription(for frame: SpectralFrame) -> String {
        guard let latest = history.latest() else { return "Selected slice" }
        let age = max(0, latest.timestamp - frame.timestamp)
        if age < 0.05 {
            return "Newest slice"
        }
        return String(format: "%.1f s ago", age)
    }

    private func startCapture() {
        guard isSceneActive else {
            shouldResumeWhenActive = true
            phase = .paused
            return
        }
        do {
            try analyzer.start()
            phase = .running
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadUITestHistory() {
        guard history.count == 0 else { return }

        let sampleRate = 48_000.0
        let fftSize = 4_096
        let binCount = fftSize / 2
        let timeStep = 1_024.0 / sampleRate

        var templates: [[Float]] = []
        for pattern in 0..<8 {
            var magnitudes = [Float](repeating: -110, count: binCount)
            for bin in 0..<binCount {
                let frequency = Double(bin) * sampleRate / Double(fftSize)
                let texture = -106.0 + 2.0 * sin(Double(bin) * 0.071 + Double(pattern) * 0.35)
                let firstPeak = -23.0 - 0.025 * pow(frequency - 440, 2)
                let secondPeak = -34.0 - 0.012 * pow(frequency - 1_000, 2)
                magnitudes[bin] = Float(max(texture, firstPeak, secondPeak))
            }
            templates.append(magnitudes)
        }

        for row in 0..<192 {
            history.append(
                SpectralFrame(
                    timestamp: Double(row) * timeStep,
                    sampleRate: sampleRate,
                    fftSize: fftSize,
                    magnitudesDB: templates[row % templates.count]
                )
            )
        }

        framesCaptured = history.count
        if let frame = history.latest() {
            latestPeak = PeakDetector.strongestPeak(
                in: frame,
                maximumFrequency: FrequencyScale.defaultMaximum
            )
        }
    }

    private func observeAudioEvents() {
        let interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            Task { @MainActor in
                switch type {
                case .began:
                    self.wasRunningBeforeInterruption = self.phase == .running
                    self.analyzer.pause()
                    self.phase = .interrupted
                case .ended:
                    let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                    if self.wasRunningBeforeInterruption, options.contains(.shouldResume) {
                        self.startCapture()
                    } else {
                        self.phase = .paused
                    }
                    self.wasRunningBeforeInterruption = false
                @unknown default:
                    break
                }
            }
        }
        notificationTokens.append(interruptionToken)

        let routeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      self.phase == .running,
                      !self.isRestartingForRouteChange,
                      let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
                      reason != .categoryChange,
                      reason != .override else { return }
                self.isRestartingForRouteChange = true
                self.analyzer.stop()
                self.startCapture()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isRestartingForRouteChange = false
                }
            }
        }
        notificationTokens.append(routeToken)
    }
}
