import XCTest
@testable import Spectrogram

final class AudioSampleRingBufferTests: XCTestCase {
    func testOverflowKeepsNewestSamplesInOrder() {
        let ring = AudioSampleRingBuffer(capacity: 4)
        write([1, 2, 3], to: ring)
        write([4, 5, 6], to: ring)

        var output = [Float](repeating: 0, count: 4)
        XCTAssertEqual(ring.read(into: &output), 4)
        XCTAssertEqual(output, [3, 4, 5, 6])
        XCTAssertTrue(ring.finishDrainingIfEmpty())
    }

    func testOnlyFirstWriterSchedulesDrain() {
        let ring = AudioSampleRingBuffer(capacity: 8)
        XCTAssertTrue(write([1, 2], to: ring))
        XCTAssertFalse(write([3, 4], to: ring))

        var output = [Float](repeating: 0, count: 8)
        XCTAssertEqual(ring.read(into: &output), 4)
        XCTAssertTrue(ring.finishDrainingIfEmpty())
        XCTAssertTrue(write([5], to: ring))
    }

    @discardableResult
    private func write(_ values: [Float], to ring: AudioSampleRingBuffer) -> Bool {
        values.withUnsafeBufferPointer { buffer in
            ring.write(buffer.baseAddress!, count: buffer.count)
        }
    }
}
