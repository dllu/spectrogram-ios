import Foundation

public struct SpectrumPeak: Equatable, Sendable {
    public let index: Int
    public let binPosition: Double
    public let frequency: Double
    public let magnitudeDB: Float

    public init(index: Int, binPosition: Double, frequency: Double, magnitudeDB: Float) {
        self.index = index
        self.binPosition = binPosition
        self.frequency = frequency
        self.magnitudeDB = magnitudeDB
    }
}

public enum PeakDetector {
    public static func strongestPeak(
        in frame: SpectralFrame,
        minimumFrequency: Double = FrequencyScale.defaultMinimum,
        maximumFrequency: Double? = nil
    ) -> SpectrumPeak? {
        localPeaks(
            in: frame,
            minimumFrequency: minimumFrequency,
            maximumFrequency: maximumFrequency
        ).max { $0.magnitudeDB < $1.magnitudeDB }
    }

    public static func nearestPeak(
        to frequency: Double,
        in frame: SpectralFrame,
        minimumFrequency: Double = FrequencyScale.defaultMinimum,
        maximumFrequency: Double? = nil
    ) -> SpectrumPeak? {
        let peaks = localPeaks(
            in: frame,
            minimumFrequency: minimumFrequency,
            maximumFrequency: maximumFrequency
        )
        guard frequency > 0 else { return peaks.first }
        return peaks.min {
            abs(log($0.frequency / frequency)) < abs(log($1.frequency / frequency))
        }
    }

    public static func localPeaks(
        in frame: SpectralFrame,
        minimumFrequency: Double = FrequencyScale.defaultMinimum,
        maximumFrequency: Double? = nil
    ) -> [SpectrumPeak] {
        let values = frame.magnitudesDB
        guard values.count >= 3, frame.fftSize > 0, frame.sampleRate > 0 else { return [] }

        let upperFrequency = min(maximumFrequency ?? frame.nyquistFrequency, frame.nyquistFrequency)
        let lowerIndex = max(1, Int(ceil(frame.binPosition(forFrequency: minimumFrequency))))
        let upperIndex = min(values.count - 2, Int(floor(frame.binPosition(forFrequency: upperFrequency))))
        guard lowerIndex <= upperIndex else { return [] }

        var peaks: [SpectrumPeak] = []
        peaks.reserveCapacity(max(8, (upperIndex - lowerIndex) / 16))

        for index in lowerIndex...upperIndex {
            let left = values[index - 1]
            let center = values[index]
            let right = values[index + 1]
            guard center >= left, center >= right, center > left || center > right else { continue }
            peaks.append(interpolatedPeak(index: index, frame: frame))
        }

        if peaks.isEmpty,
           let index = values[lowerIndex...upperIndex].indices.max(by: { values[$0] < values[$1] }) {
            peaks.append(interpolatedPeak(index: index, frame: frame))
        }
        return peaks
    }

    private static func interpolatedPeak(index: Int, frame: SpectralFrame) -> SpectrumPeak {
        let values = frame.magnitudesDB
        let left = Double(values[index - 1])
        let center = Double(values[index])
        let right = Double(values[index + 1])
        let denominator = left - (2 * center) + right

        var offset = 0.0
        if denominator.isFinite, abs(denominator) > .ulpOfOne {
            offset = 0.5 * (left - right) / denominator
            offset = min(max(offset, -0.5), 0.5)
        }

        let interpolatedMagnitude = center - 0.25 * (left - right) * offset
        let binPosition = Double(index) + offset
        return SpectrumPeak(
            index: index,
            binPosition: binPosition,
            frequency: frame.frequency(forBinPosition: binPosition),
            magnitudeDB: Float(interpolatedMagnitude)
        )
    }
}
