import MetalKit
import SpectrogramCore

private struct SpectrogramUniforms {
    var latestRow: UInt32 = 0
    var validRows: UInt32 = 0
    var textureHeight: UInt32 = 0
    var textureWidth: UInt32 = 0
    var sampleRate: Float = 48_000
    var fftSize: Float = 4_096
    var minimumFrequency: Float = 20
    var maximumFrequency: Float = 20_000
}

enum SpectrogramRendererError: Error {
    case commandQueueUnavailable
    case shaderUnavailable
}

final class SpectrogramRenderer: NSObject, MTKViewDelegate {
    private static let floorDB: Float = -110
    private static let ceilingDB: Float = -20

    private let history: SpectrogramHistory
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    private var texture: MTLTexture?
    private var encodedRow: [UInt8] = []
    private var lastSequence: UInt64?
    private var observedGeneration: UInt64
    private var validRows = 0
    private var latestPhysicalRow = 0
    private var latestSampleRate = 48_000.0
    private var latestFFTSize = 4_096

    init(view: MTKView, history: SpectrogramHistory) throws {
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
        self.device = device
        self.commandQueue = commandQueue
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        observedGeneration = history.generation
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        synchronizeHistory()

        guard let renderPass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }

        encoder.label = "Draw spectrogram"
        if let texture {
            var uniforms = SpectrogramUniforms(
                latestRow: UInt32(latestPhysicalRow),
                validRows: UInt32(validRows),
                textureHeight: UInt32(history.capacity),
                textureWidth: UInt32(texture.width),
                sampleRate: Float(latestSampleRate),
                fftSize: Float(latestFFTSize),
                minimumFrequency: Float(FrequencyScale.defaultMinimum),
                maximumFrequency: Float(
                    FrequencyScale.displayMaximum(nyquist: latestSampleRate / 2)
                )
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
    }

    private func synchronizeHistory() {
        let generation = history.generation
        if generation != observedGeneration {
            observedGeneration = generation
            lastSequence = nil
            validRows = 0
        }

        let frames = history.frames(after: lastSequence)
        for frame in frames {
            if texture?.width != frame.magnitudesDB.count {
                makeTexture(width: frame.magnitudesDB.count)
                validRows = 0
            }
            guard let texture else { continue }

            if encodedRow.count != frame.magnitudesDB.count {
                encodedRow = Array(repeating: 0, count: frame.magnitudesDB.count)
            }
            let range = Self.ceilingDB - Self.floorDB
            for index in frame.magnitudesDB.indices {
                let normalized = (frame.magnitudesDB[index] - Self.floorDB) / range
                encodedRow[index] = UInt8((min(max(normalized, 0), 1) * 255).rounded())
            }

            let physicalRow = Int(frame.sequence % UInt64(history.capacity))
            let region = MTLRegionMake2D(0, physicalRow, texture.width, 1)
            encodedRow.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    withBytes: baseAddress,
                    bytesPerRow: texture.width
                )
            }

            latestPhysicalRow = physicalRow
            latestSampleRate = frame.sampleRate
            latestFFTSize = frame.fftSize
            validRows = min(validRows + 1, history.capacity)
            lastSequence = frame.sequence
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
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        texture = device.makeTexture(descriptor: descriptor)
        texture?.label = "Spectrogram history"
        encodedRow = Array(repeating: 0, count: width)
    }
}
