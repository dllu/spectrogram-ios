import Foundation

public enum FrequencyScale {
    public static let defaultMinimum = 32.0
    public static let defaultMaximum = 16_000.0

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
            1_000, 2_000, 5_000, 10_000, 16_000, 20_000, 24_000,
        ]
        return Array(Set([minimum, maximum] + candidates.filter { $0 >= minimum && $0 <= maximum })).sorted()
    }

    /// Octaves anchored at 1 kHz: 31.25, 62.5, 125, 250, 500, 1k, 2k…
    /// A fixed reference keeps tick positions stable when the range changes.
    public static func octaveTicks(minimum: Double, maximum: Double) -> [Double] {
        guard minimum.isFinite, maximum.isFinite, minimum > 0, maximum >= minimum else { return [] }
        let firstExponent = ceil(log2(minimum) - log2(1_000.0))
        var frequency = 1_000 * pow(2, firstExponent)
        var result: [Double] = []
        while frequency.isFinite, frequency > 0, frequency <= maximum, result.count < 64 {
            result.append(frequency)
            frequency *= 2
        }
        return result
    }

    public static func halfOctaveTicks(minimum: Double, maximum: Double) -> [Double] {
        octaveTicks(minimum: minimum / sqrt(2), maximum: maximum / sqrt(2)).map { $0 * sqrt(2) }
    }

    /// Keeps endpoint labels and drops interior labels that would overlap.
    public static func ticks(minimum: Double = defaultMinimum, maximum: Double, width: Double, minimumSpacing: Double = 44) -> [Double] {
        let candidates = ticks(minimum: minimum, maximum: maximum)
        guard let first = candidates.first, let last = candidates.last else { return [] }
        guard width >= minimumSpacing, first != last else { return [first] }
        var result = [first]
        let lastX = normalizedPosition(for: last, minimum: minimum, maximum: maximum) * width
        var previousX = normalizedPosition(for: first, minimum: minimum, maximum: maximum) * width
        for frequency in candidates.dropFirst().dropLast() {
            let x = normalizedPosition(for: frequency, minimum: minimum, maximum: maximum) * width
            if x - previousX >= minimumSpacing, lastX - x >= minimumSpacing {
                result.append(frequency)
                previousX = x
            }
        }
        if lastX - previousX >= minimumSpacing { result.append(last) }
        return result
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
        if frequency.rounded() != frequency {
            return String(format: "%.2f", frequency)
                .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        }
        return String(format: "%.0f", frequency)
    }
}
