import Foundation

/// Shares a fractional, buffered playhead with rendering and slice picking.
/// Audio rows remain discrete; display motion advances at the audio hop rate.
public final class SpectrogramScrollClock: @unchecked Sendable {
    private let lock = NSLock()
    private var startPosition: Double?
    private var targetPosition = 0.0
    private var startTime = 0.0
    private var interval = 1_024.0 / 48_000
    private var running = false

    public init() {}

    public func update(sequence: UInt64, interval: TimeInterval, at time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        let next = Double(sequence)
        guard let start = startPosition else {
            // A small buffer absorbs audio delivery and display scheduling jitter.
            // Newest uploaded rows start below the visible upper edge.
            startPosition = max(1, next - 1.5)
            targetPosition = next
            startTime = time
            self.interval = min(max(interval, 0.001), 0.25)
            return
        }
        guard next != targetPosition else { return }
        let elapsedRows = max(0, time - startTime) / self.interval
        // If capture stalled, resume from the held position instead of jumping
        // ahead by the time spent without samples. Paused picking stays fixed.
        if running, start + elapsedRows > targetPosition {
            startPosition = targetPosition
            startTime = time
        } else if self.interval != interval {
            startPosition = positionLocked(at: time)
            startTime = time
        }
        targetPosition = next
        self.interval = min(max(interval, 0.001), 0.25)
    }

    public func setRunning(_ value: Bool, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lock.lock()
        defer { lock.unlock() }
        guard running != value else { return }
        startPosition = positionLocked(at: time)
        startTime = time
        running = value
    }

    public func position(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return positionLocked(at: time)
    }

    public func reset() {
        lock.lock()
        startPosition = nil
        targetPosition = 0
        lock.unlock()
    }

    private func positionLocked(at time: TimeInterval) -> Double? {
        guard let startPosition else { return nil }
        guard running else { return startPosition }
        return min(targetPosition, startPosition + max(0, time - startTime) / interval)
    }
}
