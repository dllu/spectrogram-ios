// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpectrogramCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SpectrogramCore", targets: ["SpectrogramCore"]),
    ],
    targets: [
        .target(
            name: "SpectrogramCore",
            path: "Spectrogram/Sources/SpectrogramCore"
        ),
        .testTarget(
            name: "SpectrogramCoreTests",
            dependencies: ["SpectrogramCore"],
            path: "Spectrogram/Tests/SpectrogramCoreTests"
        ),
    ]
)
