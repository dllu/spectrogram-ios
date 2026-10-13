import XCTest
@testable import SpectrogramCore

final class FrequencyScaleTests: XCTestCase {
    func testLogarithmicScaleRoundTrips() {
        let maximum = 20_000.0
        for frequency in [32.0, 50, 440, 1_000, 8_000, 20_000] {
            let position = FrequencyScale.normalizedPosition(for: frequency, maximum: maximum)
            XCTAssertEqual(
                FrequencyScale.frequency(at: position, maximum: maximum),
                frequency,
                accuracy: 0.000_001
            )
        }
    }

    func testScaleClampsOutsideValues() {
        XCTAssertEqual(FrequencyScale.frequency(at: -1, maximum: 20_000), 32)
        XCTAssertEqual(FrequencyScale.frequency(at: 2, maximum: 20_000), 20_000)
        XCTAssertEqual(FrequencyScale.normalizedPosition(for: 1, maximum: 20_000), 0)
        XCTAssertEqual(FrequencyScale.normalizedPosition(for: 30_000, maximum: 20_000), 1)
    }
    func testCompactTicksKeepEndpointsWithoutOverlapping() {
        for width in [100.0, 240, 320, 768] {
            let ticks = FrequencyScale.ticks(maximum: 20_000, width: width)
            XCTAssertEqual(ticks.first, 32)
            XCTAssertEqual(ticks.last, 20_000)
            for (left, right) in zip(ticks, ticks.dropFirst()) {
                let distance = (FrequencyScale.normalizedPosition(for: right, maximum: 20_000)
                    - FrequencyScale.normalizedPosition(for: left, maximum: 20_000)) * width
                XCTAssertGreaterThanOrEqual(distance, 44 - 0.000_001)
            }
        }
        XCTAssertEqual(FrequencyScale.ticks(maximum: 20_000, width: 20), [32])
        XCTAssertEqual(FrequencyScale.ticks(maximum: 32, width: 320), [32])
    }
    func testOctaveTicksDoubleAndStayAlignedWhenRangeChanges() {
        let ticks = FrequencyScale.octaveTicks(minimum: 32, maximum: 16_000)
        XCTAssertEqual(ticks, [62.5, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000])
        for (left, right) in zip(ticks, ticks.dropFirst()) {
            XCTAssertEqual(right / left, 2)
        }
        XCTAssertEqual(FrequencyScale.octaveTicks(minimum: 100, maximum: 3_000), [125, 250, 500, 1_000, 2_000])
        XCTAssertEqual(FrequencyScale.octaveTicks(minimum: 0, maximum: 16_000), [])
        XCTAssertEqual(FrequencyScale.label(for: 62.5), "62.5")
        let minor = FrequencyScale.halfOctaveTicks(minimum: 32, maximum: 16_000)
        XCTAssertTrue(minor.allSatisfy { $0 >= 32 && $0 <= 16_000 })
        XCTAssertEqual(minor.first!, 31.25 * sqrt(2), accuracy: 0.000001)
    }

}
