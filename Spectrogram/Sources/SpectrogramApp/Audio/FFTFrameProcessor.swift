import Accelerate
import Foundation

final class FFTFrameProcessor {
    let sampleRate: Double
    let fftSize: Int
    let hopSize: Int

    private let log2FFTSize: vDSP_Length
    private let fftSetup: FFTSetup
    private let windowScale: Float

    private var sampleRing: [Float]
    private var writeIndex = 0
    private var availableSamples = 0
    private var samplesSinceFrame = 0
    private var hasEmittedFrame = false
    private var totalSamples: UInt64 = 0

    private var window: [Float]
    private var windowedSamples: [Float]
    private var realParts: [Float]
    private var imaginaryParts: [Float]
    private var magnitudes: [Float]
    private var decibels: [Float]

    init(sampleRate: Double, fftSize: Int = 4_096, hopSize: Int = 1_024) {
        precondition(fftSize > 1 && fftSize.nonzeroBitCount == 1)
        precondition(hopSize > 0 && hopSize <= fftSize)

        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.hopSize = hopSize
        log2FFTSize = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2FFTSize, FFTRadix(kFFTRadix2)) else {
            preconditionFailure("Unable to create FFT setup")
        }
        fftSetup = setup

        sampleRing = Array(repeating: 0, count: fftSize)
        window = Array(repeating: 0, count: fftSize)
        windowedSamples = Array(repeating: 0, count: fftSize)
        realParts = Array(repeating: 0, count: fftSize / 2)
        imaginaryParts = Array(repeating: 0, count: fftSize / 2)
        magnitudes = Array(repeating: 0, count: fftSize / 2)
        decibels = Array(repeating: 0, count: fftSize / 2)

        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        let coherentGain = max(window.reduce(0, +), .leastNonzeroMagnitude)
        windowScale = 2 / coherentGain
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func ingest(_ samples: UnsafeBufferPointer<Float>, onFrame: (SpectralFrame) -> Void) {
        for sample in samples {
            sampleRing[writeIndex] = sample
            writeIndex = (writeIndex + 1) % fftSize
            totalSamples &+= 1

            if availableSamples < fftSize {
                availableSamples += 1
            }

            if availableSamples == fftSize, !hasEmittedFrame {
                hasEmittedFrame = true
                samplesSinceFrame = 0
                onFrame(makeFrame())
            } else if hasEmittedFrame {
                samplesSinceFrame += 1
                if samplesSinceFrame >= hopSize {
                    samplesSinceFrame = 0
                    onFrame(makeFrame())
                }
            }
        }
    }

    func reset() {
        sampleRing = Array(repeating: 0, count: fftSize)
        writeIndex = 0
        availableSamples = 0
        samplesSinceFrame = 0
        hasEmittedFrame = false
        totalSamples = 0
    }

    private func makeFrame() -> SpectralFrame {
        for index in 0..<fftSize {
            windowedSamples[index] = sampleRing[(writeIndex + index) % fftSize] * window[index]
        }

        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imaginaryParts.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var splitComplex = DSPSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imaginaryBuffer.baseAddress!
                )

                windowedSamples.withUnsafeBytes { rawBuffer in
                    let complex = rawBuffer.baseAddress!.assumingMemoryBound(to: DSPComplex.self)
                    vDSP_ctoz(
                        complex,
                        2,
                        &splitComplex,
                        1,
                        vDSP_Length(fftSize / 2)
                    )
                }

                vDSP_fft_zrip(
                    fftSetup,
                    &splitComplex,
                    1,
                    log2FFTSize,
                    FFTDirection(FFT_FORWARD)
                )

                // In a packed real FFT imag[0] contains Nyquist. This app stores bins
                // [0, Nyquist), so clear it before calculating vector magnitudes.
                imaginaryBuffer[0] = 0
                magnitudes.withUnsafeMutableBufferPointer { magnitudeBuffer in
                    vDSP_zvabs(
                        &splitComplex,
                        1,
                        magnitudeBuffer.baseAddress!,
                        1,
                        vDSP_Length(fftSize / 2)
                    )
                }
            }
        }

        var scale = windowScale
        vDSP_vsmul(
            magnitudes,
            1,
            &scale,
            &magnitudes,
            1,
            vDSP_Length(magnitudes.count)
        )
        magnitudes[0] *= 0.5

        var amplitudeFloor: Float = 0.000_001
        vDSP_vthr(
            magnitudes,
            1,
            &amplitudeFloor,
            &magnitudes,
            1,
            vDSP_Length(magnitudes.count)
        )
        var reference: Float = 1
        vDSP_vdbcon(
            magnitudes,
            1,
            &reference,
            &decibels,
            1,
            vDSP_Length(decibels.count),
            0
        )

        return SpectralFrame(
            timestamp: Double(totalSamples) / sampleRate,
            sampleRate: sampleRate,
            fftSize: fftSize,
            magnitudesDB: decibels
        )
    }
}
