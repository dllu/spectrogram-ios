import XCTest
@testable import SpectrogramCore

final class SpectrogramHistoryTests: XCTestCase {
    func testHistoryWrapsAndPreservesOrder() {
        let history = SpectrogramHistory(capacity: 3)
        for timestamp in 0..<5 {
            history.append(frame(timestamp: Double(timestamp)))
        }

        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history.snapshot().map(\.timestamp), [2, 3, 4])
        XCTAssertEqual(history.frame(age: 0)?.timestamp, 4)
        XCTAssertEqual(history.frame(age: 2)?.timestamp, 2)
        XCTAssertNil(history.frame(age: 3))
    }

    func testVerticalSelectionRunsOldestToNewest() {
        let history = SpectrogramHistory(capacity: 5)
        for timestamp in 0..<5 {
            history.append(frame(timestamp: Double(timestamp)))
        }

        XCTAssertEqual(history.frame(normalizedYFromTop: 0)?.timestamp, 0)
        XCTAssertEqual(history.frame(normalizedYFromTop: 0.5)?.timestamp, 2)
        XCTAssertEqual(history.frame(normalizedYFromTop: 1)?.timestamp, 4)
    }

    func testIncrementalFramesSurviveReaderFallingBehind() {
        let history = SpectrogramHistory(capacity: 3)
        let first = history.append(frame(timestamp: 0))
        history.append(frame(timestamp: 1))
        XCTAssertEqual(history.frames(after: first.sequence).map(\.timestamp), [1])

        history.append(frame(timestamp: 2))
        history.append(frame(timestamp: 3))
        history.append(frame(timestamp: 4))
        XCTAssertEqual(history.frames(after: first.sequence).map(\.timestamp), [2, 3, 4])
    }

    private func frame(timestamp: TimeInterval) -> SpectralFrame {
        SpectralFrame(
            timestamp: timestamp,
            sampleRate: 48_000,
            fftSize: 4_096,
            magnitudesDB: [-100, -80]
        )
    }
}
