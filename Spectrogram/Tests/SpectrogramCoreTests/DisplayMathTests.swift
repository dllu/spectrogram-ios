import XCTest
@testable import SpectrogramCore

final class DisplayMathTests: XCTestCase {
    func testNoteReferenceAndOctaves() throws {
        let a = try XCTUnwrap(MusicalNote(frequency: 440))
        XCTAssertEqual(a.name, "A4")
        XCTAssertEqual(a.cents, 0, accuracy: 0.000001)
        XCTAssertEqual(a.differenceHz, 0, accuracy: 0.000001)
        XCTAssertEqual(MusicalNote(frequency: 220)?.name, "A3")
        XCTAssertEqual(MusicalNote(frequency: 880)?.name, "A5")
        XCTAssertEqual(MusicalNote(frequency: 261.625565)?.name, "C4")
        XCTAssertNil(MusicalNote(frequency: 0))
        XCTAssertNil(MusicalNote(frequency: .nan))
    }

    func testDetuningAndSemitoneBoundary() throws {
        let sharp = try XCTUnwrap(MusicalNote(frequency: 440 * pow(2, 25.0 / 1200)))
        XCTAssertEqual(sharp.name, "A4")
        XCTAssertEqual(sharp.cents, 25, accuracy: 0.000001)
        XCTAssertGreaterThan(sharp.differenceHz, 0)
        let flat = try XCTUnwrap(MusicalNote(frequency: 440 * pow(2, -25.0 / 1200)))
        XCTAssertEqual(flat.cents, -25, accuracy: 0.000001)
        XCTAssertLessThan(flat.differenceHz, 0)
        XCTAssertEqual(MusicalNote(frequency: 440 * pow(2, 51.0 / 1200))?.name, "A♯4")
    }

    func testFrequencyRangeClampsAndFitsLowRateMicrophones() {
        XCTAssertEqual(FrequencyRange.standard.minimum, 32)
        XCTAssertEqual(FrequencyRange.standard.maximum, 16_000)
        let invalid = FrequencyRange(minimum: -20, maximum: 10)
        XCTAssertGreaterThan(invalid.maximum, invalid.minimum)
        let limited = FrequencyRange(minimum: 10_000, maximum: 24_000).limited(to: 4_000)
        XCTAssertEqual(limited.maximum, 4_000)
        XCTAssertLessThan(limited.minimum, limited.maximum)
        let range = FrequencyRange.standard
        for frequency in [32.0, 50, 440, 16_000] {
            let x = FrequencyScale.normalizedPosition(for: frequency, minimum: range.minimum, maximum: range.maximum)
            XCTAssertEqual(FrequencyScale.frequency(at: x, minimum: range.minimum, maximum: range.maximum), frequency, accuracy: 0.000001)
        }
    }

    func testScrollTweenIsContinuousAcrossChunkArrivalsAndPause() throws {
        let clock = SpectrogramScrollClock()
        clock.setRunning(true, at: 0)
        clock.update(sequence: 100, interval: 0.02, at: 0)
        clock.update(sequence: 101, interval: 0.02, at: 0.02)
        XCTAssertEqual(try XCTUnwrap(clock.position(at: 0.02)), 99.5, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(clock.position(at: 0.03)), 100, accuracy: 0.000001)
        let before = try XCTUnwrap(clock.position(at: 0.035))
        clock.update(sequence: 102, interval: 0.02, at: 0.035)
        XCTAssertEqual(try XCTUnwrap(clock.position(at: 0.035)), before, accuracy: 0.000001)
        clock.setRunning(false, at: 0.04)
        let paused = clock.position(at: 0.04)
        XCTAssertEqual(clock.position(at: 10), paused)
        clock.update(sequence: 103, interval: 0.02, at: 10)
        XCTAssertEqual(clock.position(at: 11), paused)
        clock.setRunning(true, at: 11)
        XCTAssertEqual(try XCTUnwrap(clock.position(at: 11.02)), 101.5, accuracy: 0.000001)
        clock.reset()
        XCTAssertNil(clock.position(at: 12))
    }
    func testScrollAdvancesAt120HzWithoutNewChunksAndHoldsOnStall() throws {
        let clock = SpectrogramScrollClock()
        clock.setRunning(true, at: 0)
        clock.update(sequence: 1_000, interval: 0.02, at: 0)
        let first = try XCTUnwrap(clock.position(at: 0))
        for step in 1...3 {
            XCTAssertEqual(try XCTUnwrap(clock.position(at: Double(step) / 120)),
                           first + Double(step) / 120 / 0.02, accuracy: 0.000001)
        }
        XCTAssertEqual(clock.position(at: 5), 1_000)
        clock.update(sequence: 1_001, interval: 0.02, at: 5)
        XCTAssertEqual(clock.position(at: 5), 1_000)
        XCTAssertEqual(try XCTUnwrap(clock.position(at: 5.01)), 1_000.5, accuracy: 0.000001)
    }

}
