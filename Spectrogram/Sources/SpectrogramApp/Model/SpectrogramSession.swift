import AVFoundation
import Combine
import Foundation
import SpectrogramCore

@MainActor
final class SpectrogramSession: ObservableObject {
    static let historyCapacity = 1_024

    // Reserve more than the audio handoff's maximum burst (128 FFT hops),
    // plus the fractional playhead's interpolation rows, below the viewport.
    static let offscreenRowCapacity = 256
    let history = SpectrogramHistory(
        capacity: historyCapacity + offscreenRowCapacity,
        visibleRowCount: historyCapacity
    )

    let scrollClock = SpectrogramScrollClock()
    @Published private(set) var phase: CapturePhase = .idle {
        didSet { scrollClock.setRunning(phase.isCapturing) }
    }
    @Published var frequencyRange = FrequencyRange.standard {
        didSet {
            if !isUITesting {
                UserDefaults.standard.set(frequencyRange.minimum, forKey: "frequencyMinimum")
                UserDefaults.standard.set(frequencyRange.maximum, forKey: "frequencyMaximum")
            }
            refreshPeaks()
        }
    }
    @Published var displayFloor = -90.0 {
        didSet { if !isUITesting { UserDefaults.standard.set(displayFloor, forKey: "displayFloor") } }
    }
    @Published var contrast = 1.35 {
        didSet { if !isUITesting { UserDefaults.standard.set(contrast, forKey: "displayContrast") } }
    }
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
        if !isUITesting {
            let defaults = UserDefaults.standard
            frequencyRange = FrequencyRange(
                minimum: defaults.object(forKey: "frequencyMinimum") as? Double ?? 32,
                maximum: defaults.object(forKey: "frequencyMaximum") as? Double ?? 16_000
            )
            displayFloor = min(max(defaults.object(forKey: "displayFloor") as? Double ?? -90, -120), -60)
            contrast = min(max(defaults.object(forKey: "displayContrast") as? Double ?? 1.35, 0.75), 2)
        }
        let history = self.history
        analyzer.onFrame = { [weak self, history] frame, shouldPublish in
            let generation = history.generation
            let storedFrame = history.append(frame)
            guard shouldPublish else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.phase.isCapturing,
                      history.generation == generation else { return }
                self.latestPeak = self.strongestPeak(in: storedFrame)
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

        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission
            handlePermission(granted: permission == .granted, denied: permission == .denied)
        } else {
            handleLegacyPermission()
        }
    }

    private func handlePermission(granted: Bool, denied: Bool) {
        if granted { startCapture(); return }
        if denied { phase = .permissionDenied; return }
        phase = .requestingPermission
        Task { @MainActor [weak self] in
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = await AVAudioApplication.requestRecordPermission()
            } else {
                granted = await self?.requestLegacyPermission() ?? false
            }
            guard let self else { return }
            if granted { self.startCapture() } else { self.phase = .permissionDenied }
        }
    }

    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private func handleLegacyPermission() {
        let permission = AVAudioSession.sharedInstance().recordPermission
        handlePermission(granted: permission == .granted, denied: permission == .denied)
    }

    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private func requestLegacyPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
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
            latestPeak = strongestPeak(in: frame)
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
        let clampedY = min(max(y, 0), 1)
        guard let position = scrollClock.position() else { return }
        let sequence = (position - clampedY * Double(history.visibleRowCount - 1)).rounded()
        guard sequence >= 1, let frame = history.frame(sequence: UInt64(sequence)) else { return }

        if phase == .running { pause() }
        selection = SpectrumSelection(
            frame: frame,
            peak: strongestPeak(in: frame),
            tappedNormalizedY: clampedY
        )
    }

    func selectPeak(normalizedX: Double) {
        guard var selection else { return }
        let range = frequencyRange.limited(to: selection.frame.nyquistFrequency)
        let frequency = FrequencyScale.frequency(at: normalizedX, minimum: range.minimum, maximum: range.maximum)
        let peak = PeakDetector.nearestPeak(
            to: frequency,
            in: selection.frame,
            minimumFrequency: range.minimum,
            maximumFrequency: range.maximum
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
        scrollClock.reset()
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

        for row in 0..<history.capacity {
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
            latestPeak = strongestPeak(in: frame)
        }
    }

    private func strongestPeak(in frame: SpectralFrame) -> SpectrumPeak? {
        let range = frequencyRange.limited(to: frame.nyquistFrequency)
        return PeakDetector.strongestPeak(in: frame, minimumFrequency: range.minimum, maximumFrequency: range.maximum)
    }

    private func refreshPeaks() {
        if let frame = history.latest() { latestPeak = strongestPeak(in: frame) }
        if var selected = selection {
            selected.peak = strongestPeak(in: selected.frame)
            selection = selected
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
