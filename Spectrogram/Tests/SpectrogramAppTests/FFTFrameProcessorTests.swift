import SpectrogramCore
import XCTest
@testable import Spectrogram

final class FFTFrameProcessorTests: XCTestCase {
    func testSineWaveProducesCorrectInterpolatedPeak() throws {
        let sampleRate = 48_000.0
        let processor = FFTFrameProcessor(sampleRate: sampleRate)
        let samples = (0..<8_192).map { index in
            Float(sin(2 * Double.pi * 1_000 * Double(index) / sampleRate))
        }
        var frames: [SpectralFrame] = []

        samples.withUnsafeBufferPointer { buffer in
            processor.ingest(buffer) { frames.append($0) }
        }

        XCTAssertEqual(frames.count, 5)
        let frame = try XCTUnwrap(frames.last)
        let peak = try XCTUnwrap(PeakDetector.strongestPeak(in: frame, maximumFrequency: 20_000))
        XCTAssertEqual(peak.frequency, 1_000, accuracy: 1)
        XCTAssertEqual(peak.magnitudeDB, 0, accuracy: 0.5)
    }
}
