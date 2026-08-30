import XCTest
@testable import SpectrogramCore

final class PeakDetectorTests: XCTestCase {
    func testStrongestPeakUsesParabolicInterpolation() throws {
        var values = [Float](repeating: -100, count: 16)
        values[3] = -30
        values[4] = -10
        values[5] = -20
        values[9] = -40
        values[10] = -25
        values[11] = -40
        let frame = SpectralFrame(
            timestamp: 0,
            sampleRate: 1_600,
            fftSize: 16,
            magnitudesDB: values
        )

        let peak = try XCTUnwrap(PeakDetector.strongestPeak(in: frame))
        XCTAssertEqual(peak.index, 4)
        XCTAssertEqual(peak.binPosition, 4.166_666, accuracy: 0.000_01)
        XCTAssertEqual(peak.frequency, 416.666_6, accuracy: 0.001)
        XCTAssertGreaterThan(peak.magnitudeDB, -10)
    }

    func testNearestPeakUsesLogFrequencyDistance() throws {
        var values = [Float](repeating: -100, count: 32)
        values[4] = -10
        values[16] = -20
        let frame = SpectralFrame(
            timestamp: 0,
            sampleRate: 3_200,
            fftSize: 32,
            magnitudesDB: values
        )

        let peak = try XCTUnwrap(PeakDetector.nearestPeak(to: 1_200, in: frame))
        XCTAssertEqual(peak.index, 16)
    }
}
