import Foundation

/// Thread-safe, fixed-size storage shared by the audio and rendering queues.
public final class SpectrogramHistory: @unchecked Sendable {
    public let capacity: Int

    private let lock = NSLock()
    private var storage: [SpectralFrame?]
    private var nextSequence: UInt64 = 1
    private var storedCount = 0
    private var currentGeneration: UInt64 = 0

    public init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage = Array(repeating: nil, count: capacity)
    }

    @discardableResult
    public func append(_ frame: SpectralFrame) -> SpectralFrame {
        lock.lock()
        defer { lock.unlock() }

        var storedFrame = frame
        storedFrame.sequence = nextSequence
        storage[Int(nextSequence % UInt64(capacity))] = storedFrame
        nextSequence &+= 1
        storedCount = min(storedCount + 1, capacity)
        return storedFrame
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCount
    }

    public var latestSequence: UInt64? {
        lock.lock()
        defer { lock.unlock() }
        guard storedCount > 0 else { return nil }
        return nextSequence - 1
    }

    public var generation: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return currentGeneration
    }

    public func latest() -> SpectralFrame? {
        frame(age: 0)
    }

    /// Returns a frame by age, where zero is newest.
    public func frame(age: Int) -> SpectralFrame? {
        lock.lock()
        defer { lock.unlock() }
        guard age >= 0, age < storedCount else { return nil }
        let sequence = nextSequence - 1 - UInt64(age)
        return storage[Int(sequence % UInt64(capacity))]
    }

    /// Maps the top of the rendered history to the oldest frame and the bottom to the newest.
    public func frame(normalizedYFromTop y: Double) -> SpectralFrame? {
        lock.lock()
        defer { lock.unlock() }
        guard storedCount > 0 else { return nil }
        let clampedY = min(max(y, 0), 1)
        let age = Int(((1 - clampedY) * Double(storedCount - 1)).rounded())
        let sequence = nextSequence - 1 - UInt64(age)
        return storage[Int(sequence % UInt64(capacity))]
    }

    /// Returns all retained frames newer than `sequence`, ordered oldest to newest.
    public func frames(after sequence: UInt64?) -> [SpectralFrame] {
        lock.lock()
        defer { lock.unlock() }
        guard storedCount > 0 else { return [] }

        let oldestSequence = nextSequence - UInt64(storedCount)
        let requestedStart = sequence.map { $0 &+ 1 } ?? oldestSequence
        let start = max(oldestSequence, requestedStart)
        guard start < nextSequence else { return [] }

        return (start..<nextSequence).compactMap {
            storage[Int($0 % UInt64(capacity))]
        }
    }

    public func snapshot() -> [SpectralFrame] {
        frames(after: nil)
    }

    public func clear() {
        lock.lock()
        storage = Array(repeating: nil, count: capacity)
        storedCount = 0
        currentGeneration &+= 1
        lock.unlock()
    }
}
