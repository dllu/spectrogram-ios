import AVFoundation
import Foundation
import SpectrogramCore

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
    var onFrame: ((SpectralFrame, Bool) -> Void)?

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(
        label: "com.dllu.spectrogram.analysis",
        qos: .userInteractive
    )
    private let sampleQueue = AudioSampleRingBuffer(capacity: 131_072)
    private var drainScratch = Array(repeating: Float.zero, count: 8_192)
    private var processor: FFTFrameProcessor?
    private var tapInstalled = false
    // Owned exclusively by processingQueue.
    private var lastPublishedTimestamp = -Double.infinity

    var isRunning: Bool {
        engine.isRunning
    }

    func start() throws {
        if tapInstalled {
            if !engine.isRunning {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            }
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
        try audioSession.setPreferredSampleRate(48_000)
        try audioSession.setPreferredIOBufferDuration(0.01)
        try audioSession.setActive(true, options: [])
        var started = false
        defer {
            if !started {
                try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            }
        }

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
        processingQueue.sync {
            sampleQueue.reset()
            self.processor = processor
            lastPublishedTimestamp = -Double.infinity
        }

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
            started = true
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            processingQueue.sync {
                sampleQueue.reset()
                self.processor = nil
            }
            throw error
        }
    }

    func pause() {
        engine.pause()
        // Finish pending frames before freezing or selecting the history.
        processingQueue.sync {}
    }

    func stop() {
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        // Wait for any in-flight drain before releasing or replacing its FFT state.
        processingQueue.sync {
            sampleQueue.reset()
            processor = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func drainSamples() {
        while true {
            let count = sampleQueue.read(into: &drainScratch)
            if count > 0 {
                drainScratch.withUnsafeBufferPointer { buffer in
                    let samples = UnsafeBufferPointer(start: buffer.baseAddress, count: count)
                    processor?.ingest(samples) { [weak self] frame in
                        guard let self else { return }
                        let shouldPublish = frame.timestamp - self.lastPublishedTimestamp >= 0.1
                        if shouldPublish {
                            self.lastPublishedTimestamp = frame.timestamp
                        }
                        self.onFrame?(frame, shouldPublish)
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
