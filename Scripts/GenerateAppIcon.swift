import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// A procedural waterfall icon, matching the app's Inferno palette.
// Run: swift Scripts/GenerateAppIcon.swift
let size = 1_024
let palette: [(Double, Double, Double)] = [
    (0.002, 0.002, 0.004), (0.12, 0.045, 0.29), (0.36, 0.08, 0.43),
    (0.65, 0.16, 0.37), (0.89, 0.32, 0.20), (0.98, 0.58, 0.12),
    (0.99, 0.82, 0.25), (0.99, 0.99, 0.65),
]
var pixels = [UInt8](repeating: 0, count: size * size * 4)
for y in 0..<size {
    let time = Double(y) / Double(size)
    for x in 0..<size {
        let frequency = Double(x) / Double(size)
        let drift = 0.014 * sin(time * 9) + 0.008 * sin(time * 23)
        let peaks: [(Double, Double, Double)] = [
            (0.29 + drift, 0.025, 0.98),
            (0.46 + drift * 0.65, 0.014, 0.76),
            (0.63 + drift * 0.4, 0.011, 0.57),
            (0.78 + drift * 0.3, 0.009, 0.38),
        ]
        var intensity = 0.055
        for (center, width, strength) in peaks {
            let distance = (frequency - center) / width
            intensity = max(intensity, strength * exp(-0.5 * distance * distance))
        }
        let edge = min(1, min(time, 1 - time) / 0.16)
        intensity *= (0.75 + 0.25 * edge) * (0.96 + 0.04 * sin(time * 83))
        let position = max(0, min(1, intensity)) * Double(palette.count - 1)
        let lower = Int(position)
        let upper = min(lower + 1, palette.count - 1)
        let fraction = position - Double(lower)
        let a = palette[lower], b = palette[upper]
        let index = (y * size + x) * 4
        pixels[index] = UInt8(((a.0 * (1 - fraction) + b.0 * fraction) * 255).rounded())
        pixels[index + 1] = UInt8(((a.1 * (1 - fraction) + b.1 * fraction) * 255).rounded())
        pixels[index + 2] = UInt8(((a.2 * (1 - fraction) + b.2 * fraction) * 255).rounded())
        pixels[index + 3] = 255
    }
}
let data = Data(pixels)
let provider = CGDataProvider(data: data as CFData)!
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                    shouldInterpolate: true, intent: .defaultIntent)!
let output = URL(fileURLWithPath: "Spectrogram/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination), "Could not write app icon")
print("Generated \(output.path)")
