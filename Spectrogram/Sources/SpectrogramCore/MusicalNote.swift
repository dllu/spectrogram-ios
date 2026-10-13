import Foundation

/// Equal temperament, with concert A4 at 440 Hz. This describes a spectral peak,
/// not a fundamental-pitch estimate for a polyphonic sound.
public struct MusicalNote: Equatable, Sendable {
    public let name: String
    public let idealFrequency: Double
    public let differenceHz: Double
    public let cents: Double

    public init?(frequency: Double) {
        guard frequency.isFinite, frequency > 0 else { return nil }
        let semitones = 69 + 12 * log2(frequency / 440)
        guard semitones.isFinite, (-1_000...1_000).contains(semitones) else { return nil }
        let number = Int(semitones.rounded())
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let pitchClass = ((number % 12) + 12) % 12
        let octave = Int(floor(Double(number) / 12)) - 1
        name = "\(names[pitchClass])\(octave)"
        idealFrequency = 440 * pow(2, Double(number - 69) / 12)
        differenceHz = frequency - idealFrequency
        cents = 1_200 * log2(frequency / idealFrequency)
    }

    public var deviationLabel: String {
        String(format: "%+.1f cents · %+.2f Hz", abs(cents) < 0.05 ? 0 : cents,
               abs(differenceHz) < 0.005 ? 0 : differenceHz)
    }
}
