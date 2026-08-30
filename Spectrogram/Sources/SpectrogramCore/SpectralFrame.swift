import Foundation

/// One FFT result. Bin `i` represents `i * sampleRate / fftSize` hertz.
public struct SpectralFrame: Equatable, Sendable {
    public var sequence: UInt64
    public let timestamp: TimeInterval
    public let sampleRate: Double
    public let fftSize: Int
    public let magnitudesDB: [Float]

    public init(
        sequence: UInt64 = 0,
        timestamp: TimeInterval,
        sampleRate: Double,
        fftSize: Int,
        magnitudesDB: [Float]
    ) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.magnitudesDB = magnitudesDB
    }

    public var nyquistFrequency: Double {
        sampleRate / 2
    }

    public var binWidth: Double {
        sampleRate / Double(fftSize)
    }

    public func frequency(forBinPosition position: Double) -> Double {
        position * binWidth
    }

    public func binPosition(forFrequency frequency: Double) -> Double {
        frequency / binWidth
    }
}
