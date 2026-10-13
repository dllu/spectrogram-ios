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
    func testChunkBoundariesDoNotChangeOverlappingFrames() {
        let samples = (0..<12_345).map { Float(sin(Double($0) * 0.17)) }
        let contiguous = FFTFrameProcessor(sampleRate: 48_000)
        let chunked = FFTFrameProcessor(sampleRate: 48_000)
        var expected: [SpectralFrame] = []
        var actual: [SpectralFrame] = []
        samples.withUnsafeBufferPointer { buffer in
            contiguous.ingest(buffer) { expected.append($0) }
            var start = 0
            while start < buffer.count {
                let count = min(317, buffer.count - start)
                chunked.ingest(UnsafeBufferPointer(start: buffer.baseAddress!.advanced(by: start), count: count)) {
                    actual.append($0)
                }
                start += count
            }
        }
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.count, 9)
    }

}
