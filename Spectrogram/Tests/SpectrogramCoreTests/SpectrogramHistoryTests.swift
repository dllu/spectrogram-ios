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

    func testVerticalSelectionRunsNewestToOldest() {
        let history = SpectrogramHistory(capacity: 5)
        for timestamp in 0..<5 {
            history.append(frame(timestamp: Double(timestamp)))
        }

        XCTAssertEqual(history.frame(normalizedYFromTop: 0)?.timestamp, 4)
        XCTAssertEqual(history.frame(normalizedYFromTop: 0.5)?.timestamp, 2)
        XCTAssertEqual(history.frame(normalizedYFromTop: 1)?.timestamp, 0)
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

    func testRetentionDoesNotEvictVisibleRowsDuringFractionalScroll() throws {
        let history = SpectrogramHistory(capacity: 12, visibleRowCount: 8)
        let clock = SpectrogramScrollClock()
        clock.setRunning(true, at: 0)
        for row in 0..<12 { history.append(frame(timestamp: Double(row) * 0.02)) }
        clock.update(sequence: 12, interval: 0.02, at: 0)
        for row in 13...100 {
            let time = Double(row - 12) * 0.02
            let playhead = try XCTUnwrap(clock.position(at: time))
            let evicted = try XCTUnwrap(history.frame(age: history.capacity - 1))
            let normalizedY = (playhead - Double(evicted.sequence)) / Double(history.visibleRowCount - 1)
            XCTAssertGreaterThan(normalizedY, 1, "A row must be fully offscreen before eviction")
            history.append(frame(timestamp: time))
            clock.update(sequence: UInt64(row), interval: 0.02, at: time)
            for subframe in 0..<3 {
                let position = try XCTUnwrap(clock.position(at: time + Double(subframe) / 120))
                let bottom = position - Double(history.visibleRowCount - 1)
                XCTAssertNotNil(history.frame(sequence: UInt64(floor(bottom))))
                XCTAssertNotNil(history.frame(sequence: UInt64(ceil(bottom))))
            }
        }
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
