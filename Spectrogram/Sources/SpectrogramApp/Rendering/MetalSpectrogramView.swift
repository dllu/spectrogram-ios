import MetalKit
import SpectrogramCore
import SwiftUI

struct MetalSpectrogramView: UIViewRepresentable {
    let history: SpectrogramHistory
    let capturePaused: Bool

    private var shouldRenderContinuously: Bool {
        !capturePaused && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    final class Coordinator {
        var renderer: SpectrogramRenderer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.002, green: 0.002, blue: 0.004, alpha: 1)
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = !shouldRenderContinuously
        view.isPaused = !shouldRenderContinuously
        view.isOpaque = true

        if view.device != nil,
           let renderer = try? SpectrogramRenderer(view: view, history: history) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }
        if !shouldRenderContinuously {
            view.setNeedsDisplay()
        }
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        view.enableSetNeedsDisplay = !shouldRenderContinuously
        view.isPaused = !shouldRenderContinuously
        if !shouldRenderContinuously {
            view.setNeedsDisplay()
        }
    }
}
