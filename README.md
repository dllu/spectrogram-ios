# Spectrogram for iOS

A focused real-time microphone spectrogram for iPhone and iPad. It uses a logarithmic frequency axis and the Inferno color map by default, with no network access or third-party runtime dependencies.

## Using the app

- Tap pause/play to freeze or resume the waterfall.
- Tap any horizontal slice to freeze it and open its intensity-versus-frequency trace.
- The strongest frequency is labeled automatically. Tap anywhere on the trace to snap the label to the nearest local peak.
- Tap the trash button to clear captured history.

Microphone samples are analyzed in memory and are never recorded or transmitted.

## Architecture

`AVAudioEngine` captures 48 kHz floating-point audio. A bounded preallocated ring buffer moves samples off the real-time callback, and Accelerate performs a 4,096-point Hann-windowed FFT every 1,024 samples. A fixed 1,024-row history holds roughly 22 seconds at 48 kHz.

Metal uploads each spectrum as a single 8-bit texture row. Its fragment shader performs the logarithmic frequency lookup and Inferno color mapping, so the CPU does not redraw the waterfall. SwiftUI supplies controls, grid labels, accessibility, and the interactive spectrum trace.

## Building

Requirements: Xcode 16 or later and XcodeGen.

```sh
brew install xcodegen
xcodegen generate
open Spectrogram.xcodeproj
```

The app supports iOS 16 and later. Core frequency mapping, history, and peak interpolation also form a Swift package and can be tested with `swift test` on platforms with Swift 5.9 or later.
