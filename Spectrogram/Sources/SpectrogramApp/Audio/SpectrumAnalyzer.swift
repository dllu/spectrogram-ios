import AVFoundation
import Foundation

enum SpectrumAnalyzerError: LocalizedError {
    case microphoneUnavailable
    case unsupportedAudioFormat

    var errorDescription: String? {
        switch self {
        case .microphoneUnavailable:
            return "No microphone input is available."
        case .unsupportedAudioFormat:
            return "The microphone returned an unsupported audio format."
        }
    }
}

final class SpectrumAnalyzer {
    var onFrame: ((SpectralFrame) -> Void)?

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(
        label: "com.dllu.spectrogram.analysis",
        qos: .userInteractive
    )
    private let sampleQueue = AudioSampleRingBuffer(capacity: 131_072)
    private var drainScratch = Array(repeating: Float.zero, count: 8_192)
    private var processor: FFTFrameProcessor?
    private var tapInstalled = false

    var sampleRate: Double? {
        processor?.sampleRate
    }

    var isRunning: Bool {
        engine.isRunning
    }

    func start() throws {
        if tapInstalled {
            if !engine.isRunning {
                try engine.start()
            }
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
        try audioSession.setPreferredSampleRate(48_000)
        try audioSession.setPreferredIOBufferDuration(0.01)
        try audioSession.setActive(true, options: [])

        guard audioSession.isInputAvailable else {
            throw SpectrumAnalyzerError.microphoneUnavailable
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0,
              format.channelCount > 0,
              format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved else {
            throw SpectrumAnalyzerError.unsupportedAudioFormat
        }

        let processor = FFTFrameProcessor(sampleRate: format.sampleRate)
        self.processor = processor
        sampleQueue.reset()

        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let self,
                  let channel = buffer.floatChannelData?.pointee else { return }
            let frameCount = Int(buffer.frameLength)
            if self.sampleQueue.write(channel, count: frameCount) {
                self.processingQueue.async { [weak self] in
                    self?.drainSamples()
                }
            }
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            self.processor = nil
            throw error
        }
    }

    func pause() {
        engine.pause()
    }

    func stop() {
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        processor = nil
        sampleQueue.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func drainSamples() {
        while true {
            let count = sampleQueue.read(into: &drainScratch)
            if count > 0 {
                drainScratch.withUnsafeBufferPointer { buffer in
                    let samples = UnsafeBufferPointer(start: buffer.baseAddress, count: count)
                    processor?.ingest(samples) { [weak self] frame in
                        self?.onFrame?(frame)
                    }
                }
                continue
            }

            if sampleQueue.finishDrainingIfEmpty() {
                return
            }
        }
    }
}
