import SpectrogramCore
import SwiftUI

struct SpectrumPlotView: View {
    let selection: SpectrumSelection
    let onTap: (Double) -> Void

    private let floorDB = -110.0
    private let ceilingDB = -20.0
    private let insets = EdgeInsets(top: 18, leading: 42, bottom: 26, trailing: 12)

    var body: some View {
        GeometryReader { geometry in
            Canvas(opaque: true, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let plot = CGRect(
                    x: insets.leading,
                    y: insets.top,
                    width: max(1, size.width - insets.leading - insets.trailing),
                    height: max(1, size.height - insets.top - insets.bottom)
                )
                drawGrid(in: &context, plot: plot)
                drawSpectrum(in: &context, plot: plot)
                drawSelectedPeak(in: &context, plot: plot)
            }
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let width = geometry.size.width - insets.leading - insets.trailing
                    guard width > 0 else { return }
                    onTap((value.location.x - insets.leading) / width)
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Intensity by frequency")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Tap near a frequency to select its nearest peak")
        .accessibilityIdentifier("spectrum-plot")
    }

    private var maximumFrequency: Double {
        FrequencyScale.displayMaximum(nyquist: selection.frame.nyquistFrequency)
    }

    private var accessibilityValue: String {
        guard let peak = selection.peak else { return "No peak selected" }
        return "Peak at \(FrequencyScale.label(for: peak.frequency, precise: true)), \(String(format: "%.1f", peak.magnitudeDB)) decibels full scale"
    }

    private func drawGrid(in context: inout GraphicsContext, plot: CGRect) {
        context.fill(Path(plot), with: .color(Color(red: 0.015, green: 0.012, blue: 0.025)))

        for decibels in stride(from: -100.0, through: -20.0, by: 20) {
            let y = yPosition(decibels: decibels, plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
            context.draw(
                Text("\(Int(decibels))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62)),
                at: CGPoint(x: plot.minX - 5, y: y),
                anchor: .trailing
            )
        }

        for frequency in FrequencyScale.ticks(maximum: maximumFrequency) {
            let x = xPosition(frequency: frequency, plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(line, with: .color(.white.opacity(0.1)), lineWidth: 0.5)
            context.draw(
                Text(FrequencyScale.label(for: frequency))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.65)),
                at: CGPoint(x: x, y: plot.maxY + 6),
                anchor: .top
            )
        }
    }

    private func drawSpectrum(in context: inout GraphicsContext, plot: CGRect) {
        let pointCount = max(2, Int(plot.width.rounded(.up)))
        var fill = Path()
        var stroke = Path()

        for point in 0..<pointCount {
            let normalizedX = Double(point) / Double(pointCount - 1)
            let frequency = FrequencyScale.frequency(
                at: normalizedX,
                maximum: maximumFrequency
            )
            let decibels = interpolatedMagnitude(at: frequency)
            let position = CGPoint(
                x: plot.minX + CGFloat(normalizedX) * plot.width,
                y: yPosition(decibels: decibels, plot: plot)
            )
            if point == 0 {
                stroke.move(to: position)
                fill.move(to: CGPoint(x: position.x, y: plot.maxY))
                fill.addLine(to: position)
            } else {
                stroke.addLine(to: position)
                fill.addLine(to: position)
            }
        }
        fill.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        fill.closeSubpath()

        context.fill(
            fill,
            with: .linearGradient(
                Gradient(colors: [.orange.opacity(0.42), .purple.opacity(0.08)]),
                startPoint: CGPoint(x: plot.midX, y: plot.minY),
                endPoint: CGPoint(x: plot.midX, y: plot.maxY)
            )
        )
        context.stroke(stroke, with: .color(.orange), lineWidth: 1.35)
    }

    private func drawSelectedPeak(in context: inout GraphicsContext, plot: CGRect) {
        guard let peak = selection.peak else { return }
        let x = xPosition(frequency: peak.frequency, plot: plot)
        let y = yPosition(decibels: Double(peak.magnitudeDB), plot: plot)

        var marker = Path()
        marker.move(to: CGPoint(x: x, y: plot.minY))
        marker.addLine(to: CGPoint(x: x, y: plot.maxY))
        context.stroke(marker, with: .color(.cyan.opacity(0.75)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        context.fill(
            Path(ellipseIn: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)),
            with: .color(.cyan)
        )
    }

    private func interpolatedMagnitude(at frequency: Double) -> Double {
        let values = selection.frame.magnitudesDB
        guard !values.isEmpty else { return floorDB }
        let bin = selection.frame.binPosition(forFrequency: frequency)
        let lower = min(max(Int(floor(bin)), 0), values.count - 1)
        let upper = min(lower + 1, values.count - 1)
        let fraction = bin - Double(lower)
        return Double(values[lower]) * (1 - fraction) + Double(values[upper]) * fraction
    }

    private func xPosition(frequency: Double, plot: CGRect) -> CGFloat {
        let normalized = FrequencyScale.normalizedPosition(
            for: frequency,
            maximum: maximumFrequency
        )
        return plot.minX + CGFloat(normalized) * plot.width
    }

    private func yPosition(decibels: Double, plot: CGRect) -> CGFloat {
        let normalized = min(max((decibels - floorDB) / (ceilingDB - floorDB), 0), 1)
        return plot.maxY - CGFloat(normalized) * plot.height
    }
}
