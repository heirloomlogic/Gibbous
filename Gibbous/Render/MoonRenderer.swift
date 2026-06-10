//
//  MoonRenderer.swift
//  Gibbous
//
//  The single Metal pipeline behind every moon Gibbous draws — the on-screen
//  disc and the menu-bar glyph both come from here. It owns the device, the
//  sphere-impostor pipeline and the equirectangular albedo + normal textures,
//  and renders one frame to a `CGImage` on demand (no run loop; we redraw only
//  when the phase, look or size changes).
//

import CoreGraphics
import Foundation
import Metal
import MetalKit
import simd

/// Locates the module bundle (works in the app and in unit tests).
private final class GibbousBundleToken {}

/// How the disc should be shaded.
nonisolated enum MoonLook: Int32 {
    case modern = 0  // photoreal colour
    case blackAndWhite = 1  // desaturated
    case retro = 2  // 1-bit ordered dither of the same shaded moon
}

/// Layout-compatible mirror of `MoonUniforms` in Moon.metal.
private struct MoonUniforms {
    var sunDirection: SIMD3<Float>
    var subEarthLat: Float
    var subEarthLon: Float
    var limbDarkening: Float
    var ambient: Float
    var look: Int32
    var transparentOutside: Int32
    var ditherCell: Float
    var retroGamma: Float
    var backgroundColor: SIMD4<Float>
    var retroDark: SIMD4<Float>
    var retroLight: SIMD4<Float>
    // Appended fields — keep this order identical to MoonUniforms in Moon.metal.
    var roll: Float
    var surfaceBrightness: Float
    var surfaceContrast: Float
    var normalStrength: Float
}

/// Everything the renderer needs to draw one moon.
nonisolated struct MoonRenderRequest: Equatable {
    var phaseAngleDegrees: Double
    var subEarthLatitudeDegrees: Double = 0
    var subEarthLongitudeDegrees: Double = 0
    var look: MoonLook = .modern
    var limbDarkening: Float = 0.35
    var ambient: Float = 0.015
    /// Disc roll in degrees — the position angle of the Moon's north pole. The
    /// whole image rotates by this, so the moon "rocks" as the lunation advances.
    var rollDegrees: Double = 0
    /// Surface tone, tuned so maria/craters read like the Apple Weather moon
    /// rather than the physically dim ~12%-albedo disc.
    var surfaceBrightness: Float = 2.4  // gain on the albedo
    var surfaceContrast: Float = 1.4  // contrast around the lunar mean
    var normalStrength: Float = 1.6  // crater relief emphasis
    /// Transparent outside the disc (menu-bar glyph); otherwise the background
    /// colour fills the frame (modern card).
    var transparentOutside: Bool = true
    var backgroundColor: SIMD4<Float> = SIMD4(0.07, 0.07, 0.09, 1)
    // Retro look tuning.
    var ditherCell: Float = 1  // pixels per dither cell
    var retroGamma: Float = 0.85  // tone curve before thresholding
    var retroDark: SIMD4<Float> = SIMD4(0.02, 0.02, 0.03, 1)
    var retroLight: SIMD4<Float> = SIMD4(0.92, 0.93, 0.88, 1)
}

nonisolated enum MoonRendererError: Error {
    case noMetalDevice
    case libraryUnavailable
    case textureMissing(String)
    case renderTargetFailed
    case imageReadbackFailed
}

nonisolated final class MoonRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let albedo: MTLTexture
    private let normal: MTLTexture

    init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device else { throw MoonRendererError.noMetalDevice }
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw MoonRendererError.noMetalDevice }
        self.queue = queue

        let bundle = Bundle(for: GibbousBundleToken.self)
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            throw MoonRendererError.libraryUnavailable
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "moonVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "moonFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm_srgb
        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        let loader = MTKTextureLoader(device: device)
        self.albedo = try MoonRenderer.loadTexture("Moon", loader: loader, bundle: bundle, srgb: true)
        self.normal = try MoonRenderer.loadTexture("MoonNormal", loader: loader, bundle: bundle, srgb: false)
    }

    private static func loadTexture(
        _ name: String, loader: MTKTextureLoader,
        bundle: Bundle, srgb: Bool
    ) throws -> MTLTexture {
        guard let url = bundle.url(forResource: name, withExtension: "jpg") else {
            throw MoonRendererError.textureMissing(name)
        }
        return try loader.newTexture(
            URL: url,
            options: [
                .SRGB: srgb,
                .generateMipmaps: true,
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
            ])
    }

    /// Render one moon to a `CGImage` of `pixelSize × pixelSize`.
    func image(_ request: MoonRenderRequest, pixelSize: Int) throws -> CGImage {
        let target = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm_srgb, width: pixelSize, height: pixelSize, mipmapped: false)
        target.usage = [.renderTarget, .shaderRead]
        target.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: target) else {
            throw MoonRendererError.renderTargetFailed
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store

        guard let commandBuffer = queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else {
            throw MoonRendererError.renderTargetFailed
        }

        var uniforms = makeUniforms(request)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MoonUniforms>.stride, index: 0)
        encoder.setFragmentTexture(albedo, index: 0)
        encoder.setFragmentTexture(normal, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return try cgImage(from: texture)
    }

    private func makeUniforms(_ r: MoonRenderRequest) -> MoonUniforms {
        // Sun direction from the phase angle: 0°=new (behind), 90°=first quarter
        // (lit right), 180°=full (toward viewer), 270°=third quarter (lit left).
        let phi = Float(r.phaseAngleDegrees * .pi / 180)
        let sun = simd_normalize(SIMD3<Float>(sin(phi), 0, -cos(phi)))
        return MoonUniforms(
            sunDirection: sun,
            subEarthLat: Float(r.subEarthLatitudeDegrees * .pi / 180),
            subEarthLon: Float(r.subEarthLongitudeDegrees * .pi / 180),
            limbDarkening: r.limbDarkening,
            ambient: r.ambient,
            look: r.look.rawValue,
            transparentOutside: r.transparentOutside ? 1 : 0,
            ditherCell: r.ditherCell,
            retroGamma: r.retroGamma,
            backgroundColor: r.backgroundColor,
            retroDark: r.retroDark,
            retroLight: r.retroLight,
            roll: Float(r.rollDegrees * .pi / 180),
            surfaceBrightness: r.surfaceBrightness,
            surfaceContrast: r.surfaceContrast,
            normalStrength: r.normalStrength
        )
    }

    private func cgImage(from texture: MTLTexture) throws -> CGImage {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let didRead = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            texture.getBytes(
                base, bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return true
        }
        guard didRead else { throw MoonRendererError.imageReadbackFailed }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw MoonRendererError.imageReadbackFailed
        }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
            let image = CGImage(
                width: width, height: height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: info),
                provider: provider, decode: nil, shouldInterpolate: true,
                intent: .defaultIntent)
        else {
            throw MoonRendererError.imageReadbackFailed
        }
        return image
    }
}

// MARK: - Shared instance + app convenience

extension MoonRenderer {
    /// One renderer shared by every disc + the glyph — building it loads the
    /// 8K textures and the pipeline, so we do it once.
    static let shared: MoonRenderer? = try? MoonRenderer()
}

extension MoonRenderRequest {
    /// Build a render request from a readout and the current look. `ambient`
    /// is exposed so the menu-bar glyph can lift its dark limb without mutating
    /// the request after construction.
    init(readout: MoonReadout, style: DisplayStyle, ditherCell: Float = 1, ambient: Float = 0.015) {
        self.init(
            phaseAngleDegrees: readout.phaseAngleDegrees,
            subEarthLatitudeDegrees: readout.subEarthLatitude,
            subEarthLongitudeDegrees: readout.subEarthLongitude,
            look: style == .retro ? .retro : .modern,
            ambient: ambient,
            rollDegrees: readout.axisPositionAngleDegrees,
            transparentOutside: true,
            ditherCell: ditherCell
        )
    }
}
