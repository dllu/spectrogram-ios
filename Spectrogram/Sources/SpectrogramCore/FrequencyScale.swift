import Foundation

public enum FrequencyScale {
    public static let defaultMinimum = 20.0
    public static let defaultMaximum = 20_000.0

    public static func displayMaximum(nyquist: Double) -> Double {
        max(defaultMinimum, min(defaultMaximum, nyquist))
    }

    public static func frequency(
        at normalizedPosition: Double,
        minimum: Double = defaultMinimum,
        maximum: Double
    ) -> Double {
        guard maximum > minimum, minimum > 0 else { return minimum }
        let position = min(max(normalizedPosition, 0), 1)
        return minimum * pow(maximum / minimum, position)
    }

    public static func normalizedPosition(
        for frequency: Double,
        minimum: Double = defaultMinimum,
        maximum: Double
    ) -> Double {
        guard maximum > minimum, minimum > 0 else { return 0 }
        let clampedFrequency = min(max(frequency, minimum), maximum)
        return log(clampedFrequency / minimum) / log(maximum / minimum)
    }

    public static func ticks(minimum: Double = defaultMinimum, maximum: Double) -> [Double] {
        let candidates: [Double] = [
            20, 50, 100, 200, 500,
            1_000, 2_000, 5_000, 10_000, 20_000,
        ]
        return candidates.filter { $0 >= minimum && $0 <= maximum }
    }

    public static func label(for frequency: Double, precise: Bool = false) -> String {
        if precise {
            if frequency >= 1_000 {
                return String(format: "%.3f kHz", frequency / 1_000)
            }
            return String(format: "%.1f Hz", frequency)
        }

        if frequency >= 1_000 {
            let kilohertz = frequency / 1_000
            if kilohertz.rounded() == kilohertz {
                return String(format: "%.0fk", kilohertz)
            }
            return String(format: "%.1fk", kilohertz)
        }
        return String(format: "%.0f", frequency)
    }
}
