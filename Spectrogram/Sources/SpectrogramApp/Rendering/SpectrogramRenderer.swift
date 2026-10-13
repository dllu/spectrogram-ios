import MetalKit
import QuartzCore
import SpectrogramCore

private struct SpectrogramUniforms {
    var latestRow: UInt32 = 0
    var validRows: UInt32 = 0
    var textureHeight: UInt32 = 0
    var textureWidth: UInt32 = 0
    var sampleRate: Float = 48_000
    var fftSize: Float = 4_096
    var minimumFrequency: Float = 20
    var maximumFrequency: Float = 16_000
    var rowOffset: Float = 0
    var displayFloor: Float = -90
    var displayCeiling: Float = 0
    var contrast: Float = 1.35
    var bottomFadeFraction: Float = 0.02
}

enum SpectrogramRendererError: Error {
    case commandQueueUnavailable
    case shaderUnavailable
}

final class SpectrogramRenderer: NSObject, MTKViewDelegate {
    private static let floorDB: Float = -120
    private static let ceilingDB: Float = 0

    private let history: SpectrogramHistory
    private let scrollClock: SpectrogramScrollClock
    var frequencyRange = FrequencyRange.standard { didSet { needsRedraw = true } }
    var displayFloor: Float = -90 { didSet { needsRedraw = true } }
    var contrast: Float = 1.35 { didSet { needsRedraw = true } }
    private var needsRedraw = true
    private var frameInterval = 1_024.0 / 48_000
    private var previousTimestamp: Double?
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    private var texture: MTLTexture?
    private var lastSequence: UInt64?
    private var observedGeneration: UInt64
    private var validRows = 0
    private var latestPhysicalRow = 0
    private var latestSampleRate = 48_000.0
    private var latestFFTSize = 4_096
    private var lastDrawableSize: CGSize = .zero

    init(view: MTKView, history: SpectrogramHistory, scrollClock: SpectrogramScrollClock) throws {
        guard let device = view.device,
              let commandQueue = device.makeCommandQueue() else {
            throw SpectrogramRendererError.commandQueueUnavailable
        }
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "spectrogramVertex"),
              let fragmentFunction = library.makeFunction(name: "spectrogramFragment") else {
            throw SpectrogramRendererError.shaderUnavailable
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Spectrogram pipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        self.history = history
        self.scrollClock = scrollClock
        self.device = device
        self.commandQueue = commandQueue
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        observedGeneration = history.generation
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        // During capture, redraw the tween even between audio hops. Paused views
        // remain event-driven and do no continuous GPU work.
        guard !view.isPaused || needsRedraw || history.latestSequence != lastSequence
                || history.generation != observedGeneration || view.drawableSize != lastDrawableSize else { return }
        guard let renderPass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        synchronizeHistory(using: commandBuffer)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            lastSequence = nil
            validRows = 0
            return
        }

        encoder.label = "Draw spectrogram"
        if let texture {
            let range = frequencyRange.limited(to: latestSampleRate / 2)
            let visiblePosition = scrollClock.position() ?? Double(lastSequence ?? 0)
            var uniforms = SpectrogramUniforms(
                latestRow: UInt32(latestPhysicalRow),
                validRows: UInt32(validRows),
                textureHeight: UInt32(history.capacity),
                textureWidth: UInt32(texture.width),
                sampleRate: Float(latestSampleRate),
                fftSize: Float(latestFFTSize),
                minimumFrequency: Float(range.minimum),
                maximumFrequency: Float(range.maximum),
                rowOffset: Float(max(0, Double(lastSequence ?? 0) - visiblePosition)),
                displayFloor: displayFloor,
                displayCeiling: 0,
                contrast: contrast,
                bottomFadeFraction: Float(min(16 / max(view.bounds.height, 1), 0.1))
            )
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentBytes(
                &uniforms,
                length: MemoryLayout<SpectrogramUniforms>.stride,
                index: 0
            )
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        lastDrawableSize = view.drawableSize
        needsRedraw = false
    }

    private func synchronizeHistory(using commandBuffer: MTLCommandBuffer) {
        let generation = history.generation
        if generation != observedGeneration {
            observedGeneration = generation
            lastSequence = nil
            validRows = 0
            previousTimestamp = nil
        }

        let frames = history.frames(after: lastSequence)
        let maximumWidth = frames.reduce(0) { max($0, $1.magnitudesDB.count) }
        guard maximumWidth > 0 else { return }
        let bytesPerRow = (maximumWidth + 255) / 256 * 256
        guard let upload = device.makeBuffer(length: bytesPerRow * frames.count, options: .storageModeShared),
              let blit = commandBuffer.makeBlitCommandEncoder() else { return }
        blit.label = "Upload spectral rows"
        defer { blit.endEncoding() }
        for (rowIndex, frame) in frames.enumerated() {
            if texture?.width != frame.magnitudesDB.count {
                makeTexture(width: frame.magnitudesDB.count)
                validRows = 0
            }
            guard let texture else { continue }

            // Command-buffer copies order writes after previous GPU reads of this
            // texture. CPU-side texture.replace can race an in-flight render.
            let offset = rowIndex * bytesPerRow
            let bytes = upload.contents().advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            let range = Self.ceilingDB - Self.floorDB
            for index in frame.magnitudesDB.indices {
                let normalized = (frame.magnitudesDB[index] - Self.floorDB) / range
                bytes[index] = UInt8((min(max(normalized, 0), 1) * 255).rounded())
            }

            let physicalRow = Int(frame.sequence % UInt64(history.capacity))
            blit.copy(
                from: upload,
                sourceOffset: offset,
                sourceBytesPerRow: bytesPerRow,
                sourceBytesPerImage: bytesPerRow,
                sourceSize: MTLSize(width: texture.width, height: 1, depth: 1),
                to: texture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: physicalRow, z: 0)
            )

            if let previousTimestamp, frame.timestamp > previousTimestamp {
                frameInterval = min(max(frame.timestamp - previousTimestamp, 0.001), 0.25)
            }
            previousTimestamp = frame.timestamp
            latestPhysicalRow = physicalRow
            latestSampleRate = frame.sampleRate
            latestFFTSize = frame.fftSize
            validRows = min(validRows + 1, history.capacity)
            lastSequence = frame.sequence
        }
        if let lastSequence {
            scrollClock.update(sequence: lastSequence, interval: frameInterval, at: ProcessInfo.processInfo.systemUptime)
        }
    }

    private func makeTexture(width: Int) {
        guard width > 0 else {
            texture = nil
            return
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: history.capacity,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = .shaderRead
        texture = device.makeTexture(descriptor: descriptor)
        texture?.label = "Spectrogram history"
    }
}
