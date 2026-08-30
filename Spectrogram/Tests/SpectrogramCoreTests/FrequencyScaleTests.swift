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
}
