import Foundation
import SpectrogramCore

struct SpectrumSelection: Identifiable, Equatable {
    let id: UInt64
    let frame: SpectralFrame
    var peak: SpectrumPeak?
    let tappedNormalizedY: Double

    init(frame: SpectralFrame, peak: SpectrumPeak?, tappedNormalizedY: Double) {
        id = frame.sequence
        self.frame = frame
        self.peak = peak
        self.tappedNormalizedY = tappedNormalizedY
    }
}
