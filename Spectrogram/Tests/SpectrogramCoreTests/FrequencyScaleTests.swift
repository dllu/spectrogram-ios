import XCTest
@testable import SpectrogramCore

final class FrequencyScaleTests: XCTestCase {
    func testLogarithmicScaleRoundTrips() {
        let maximum = 20_000.0
        for frequency in [20.0, 50, 440, 1_000, 8_000, 20_000] {
            let position = FrequencyScale.normalizedPosition(for: frequency, maximum: maximum)
            XCTAssertEqual(
                FrequencyScale.frequency(at: position, maximum: maximum),
                frequency,
                accuracy: 0.000_001
            )
        }
    }

    func testScaleClampsOutsideValues() {
        XCTAssertEqual(FrequencyScale.frequency(at: -1, maximum: 20_000), 20)
        XCTAssertEqual(FrequencyScale.frequency(at: 2, maximum: 20_000), 20_000)
        XCTAssertEqual(FrequencyScale.normalizedPosition(for: 1, maximum: 20_000), 0)
        XCTAssertEqual(FrequencyScale.normalizedPosition(for: 30_000, maximum: 20_000), 1)
    }
    func testCompactTicksKeepEndpointsWithoutOverlapping() {
        for width in [100.0, 240, 320, 768] {
            let ticks = FrequencyScale.ticks(maximum: 20_000, width: width)
            XCTAssertEqual(ticks.first, 20)
            XCTAssertEqual(ticks.last, 20_000)
            for (left, right) in zip(ticks, ticks.dropFirst()) {
                let distance = (FrequencyScale.normalizedPosition(for: right, maximum: 20_000)
                    - FrequencyScale.normalizedPosition(for: left, maximum: 20_000)) * width
                XCTAssertGreaterThanOrEqual(distance, 44 - 0.000_001)
            }
        }
        XCTAssertEqual(FrequencyScale.ticks(maximum: 20_000, width: 20), [20])
        XCTAssertEqual(FrequencyScale.ticks(maximum: 20, width: 320), [20])
    }

}
