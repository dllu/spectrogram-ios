import Foundation

public struct FrequencyRange: Equatable, Sendable {
    public static let standard = FrequencyRange(minimum: 32, maximum: 16_000)
    public let minimum: Double
    public let maximum: Double

    public init(minimum: Double, maximum: Double) {
        let lower = minimum.isFinite ? min(max(minimum, 20), 10_000) : 32
        self.minimum = lower
        self.maximum = maximum.isFinite ? min(max(maximum, lower * 2), 24_000) : max(16_000, lower * 2)
    }

    public func limited(to nyquist: Double) -> FrequencyRange {
        let upper = min(maximum, max(1, nyquist))
        return FrequencyRange(uncheckedMinimum: min(minimum, upper / 2), maximum: upper)
    }

    private init(uncheckedMinimum: Double, maximum: Double) {
        minimum = uncheckedMinimum
        self.maximum = maximum
    }
}
