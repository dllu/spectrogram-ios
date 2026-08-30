import Foundation

/// A bounded handoff between AVAudioEngine's real-time callback and the FFT queue.
/// The callback only takes a short lock and copies into preallocated storage.
final class AudioSampleRingBuffer {
    private let lock = NSLock()
    private var storage: [Float]
    private var readIndex = 0
    private var writeIndex = 0
    private var storedCount = 0
    private var drainScheduled = false

    init(capacity: Int) {
        precondition(capacity > 0)
        storage = Array(repeating: 0, count: capacity)
    }

    /// Returns true only when the caller needs to schedule a new drain operation.
    func write(_ source: UnsafePointer<Float>, count originalCount: Int) -> Bool {
        guard originalCount > 0 else { return false }

        lock.lock()
        defer { lock.unlock() }

        let capacity = storage.count
        let count = min(originalCount, capacity)
        let sourceStart = source.advanced(by: originalCount - count)
        let overflow = max(0, storedCount + count - capacity)
        if overflow > 0 {
            readIndex = (readIndex + overflow) % capacity
            storedCount -= overflow
        }

        let firstCount = min(count, capacity - writeIndex)
        storage.withUnsafeMutableBufferPointer { destination in
            destination.baseAddress!
                .advanced(by: writeIndex)
                .update(from: sourceStart, count: firstCount)
            let secondCount = count - firstCount
            if secondCount > 0 {
                destination.baseAddress!
                    .update(from: sourceStart.advanced(by: firstCount), count: secondCount)
            }
        }

        writeIndex = (writeIndex + count) % capacity
        storedCount += count

        if drainScheduled {
            return false
        }
        drainScheduled = true
        return true
    }

    func read(into destination: inout [Float]) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let count = min(destination.count, storedCount)
        guard count > 0 else { return 0 }

        let firstCount = min(count, storage.count - readIndex)
        destination.withUnsafeMutableBufferPointer { output in
            storage.withUnsafeBufferPointer { input in
                output.baseAddress!
                    .update(from: input.baseAddress!.advanced(by: readIndex), count: firstCount)
                let secondCount = count - firstCount
                if secondCount > 0 {
                    output.baseAddress!
                        .advanced(by: firstCount)
                        .update(from: input.baseAddress!, count: secondCount)
                }
            }
        }

        readIndex = (readIndex + count) % storage.count
        storedCount -= count
        return count
    }

    /// Ends the current drain only if no writer added more samples in the meantime.
    func finishDrainingIfEmpty() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard storedCount == 0 else { return false }
        drainScheduled = false
        return true
    }

    func reset() {
        lock.lock()
        readIndex = 0
        writeIndex = 0
        storedCount = 0
        drainScheduled = false
        lock.unlock()
    }
}
