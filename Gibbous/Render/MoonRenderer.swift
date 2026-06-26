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
    var useBlueNoise: Int32
    var targetSize: Float
    var retroEarthshine: Float
    var retroBlackPoint: Float
    var cavityStrength: Float
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
    var surfaceBrightness: Float = 2.15  // gain on the albedo
    var surfaceContrast: Float = 1.65  // contrast around the lunar mean (deepens maria)
    var normalStrength: Float = 1.6  // crater relief emphasis (the rebuilt map carries the amplitude)
    /// Crater self-shadow: darkens slopes that tilt away from the disc normal so
    /// relief reads even where the sun is near-frontal (the gibbous face). 0 off.
    var cavityStrength: Float = 0.5
    /// Transparent outside the disc (menu-bar glyph); otherwise the background
    /// colour fills the frame (modern card).
    var transparentOutside: Bool = true
    var backgroundColor: SIMD4<Float> = SIMD4(0.07, 0.07, 0.09, 1)
    // Retro look tuning.
    var ditherCell: Float = 1  // pixels per dither cell
    var retroGamma: Float = 1.145  // tone curve before thresholding (>1 darkens midtones)
    // Shadow-side reveal: a faint albedo wash lifts the highland in shadow, then
    // the black point crushes the darker maria (and stray ambient specks) to
    // solid black so the maria read as un-dithered dark shapes.
    var retroEarthshine: Float = 0.082  // albedo → shadow-side highland stipple
    var retroBlackPoint: Float = 0.071  // tones below this stay solid black (maria → dark shapes)
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
    /// Blue-noise threshold tile for the retro dither. Optional: if it fails to
    /// load, the shader falls back to the Bayer matrix (see `useBlueNoise`).
    private let blueNoise: MTLTexture?

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
        // Optional: a missing tile just drops the retro dither back to Bayer.
        self.blueNoise = try? MoonRenderer.loadTexture(
            "BlueNoise", ext: "png", loader: loader, bundle: bundle, srgb: false, mipmaps: false)
    }

    private static func loadTexture(
        _ name: String, ext: String = "jpg", loader: MTKTextureLoader,
        bundle: Bundle, srgb: Bool, mipmaps: Bool = true
    ) throws -> MTLTexture {
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw MoonRendererError.textureMissing(name)
        }
        return try loader.newTexture(
            URL: url,
            options: [
                .SRGB: srgb,
                .generateMipmaps: mipmaps,
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

        var uniforms = makeUniforms(request, pixelSize: pixelSize)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MoonUniforms>.stride, index: 0)
        encoder.setFragmentTexture(albedo, index: 0)
        encoder.setFragmentTexture(normal, index: 1)
        // Bind a placeholder when the tile is absent; the shader won't read it
        // (useBlueNoise == 0) but Metal still requires a bound texture at index 2.
        encoder.setFragmentTexture(blueNoise ?? albedo, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Retro is a low-res 1-bit framebuffer: keep its pixels crisp on upscale.
        return try cgImage(from: texture, interpolate: request.look != .retro)
    }

    /// Unit sun direction from the phase angle: 0°=new (behind, −z), 90°=first
    /// quarter (lit right, +x), 180°=full (toward viewer, +z), 270°=third
    /// quarter (lit left, −x). Pure math, factored out so it can be unit-tested
    /// without a Metal device.
    static func sunDirection(phaseAngleDegrees: Double) -> SIMD3<Float> {
        let phi = Float(phaseAngleDegrees * .pi / 180)
        return simd_normalize(SIMD3<Float>(sin(phi), 0, -cos(phi)))
    }

    /// Libration angles in radians as the shader's `applyLibration` consumes them.
    /// The sign convention is fixed here, at the boundary: AstronomyKit reports the
    /// sub-Earth longitude east-positive, but the equirectangular maps put
    /// selenographic east on the *right* and `applyLibration` samples
    /// `atan2(Ns.x, Ns.z) = −subEarthLon` at the disc centre — so the longitude
    /// must be negated for an east-positive point to land on the right of the disc.
    /// Latitude needs no flip (north-positive already tilts the north pole forward).
    static func librationRadians(
        subEarthLatitudeDegrees lat: Double, subEarthLongitudeDegrees lon: Double
    ) -> (lat: Float, lon: Float) {
        (lat: Float(lat * .pi / 180), lon: Float(-lon * .pi / 180))
    }

    /// The selenographic (longitude, latitude) in degrees sampled at the centre of
    /// the disc for a given libration — a pure Swift mirror of the Metal
    /// `applyLibration` + texUV path. By definition the disc centre is the
    /// sub-Earth point, so this must return `(subEarthLongitude, subEarthLatitude)`;
    /// the test that it does pins the sign convention the shader depends on. East is
    /// +longitude (right of the disc), north is +latitude (top).
    static func discCentreSelenographicDegrees(
        subEarthLatitudeDegrees lat: Double, subEarthLongitudeDegrees lon: Double
    ) -> (longitude: Double, latitude: Double) {
        let lib = librationRadians(subEarthLatitudeDegrees: lat, subEarthLongitudeDegrees: lon)
        // applyLibration(N=(0,0,1), lib.lat, lib.lon), matching Moon.metal.
        let cl = cos(-Double(lib.lon))
        let sl = sin(-Double(lib.lon))
        let r1 = SIMD3<Double>(sl, 0, cl)  // (cl*0 + sl*1, 0, -sl*0 + cl*1)
        let ca = cos(-Double(lib.lat))
        let sa = sin(-Double(lib.lat))
        let ns = SIMD3<Double>(r1.x, ca * r1.y - sa * r1.z, sa * r1.y + ca * r1.z)
        let latTex = asin(max(-1, min(1, ns.y))) * 180 / .pi
        let lonTex = atan2(ns.x, ns.z) * 180 / .pi
        return (longitude: lonTex, latitude: latTex)
    }

    private func makeUniforms(_ r: MoonRenderRequest, pixelSize: Int) -> MoonUniforms {
        let sun = Self.sunDirection(phaseAngleDegrees: r.phaseAngleDegrees)
        let lib = Self.librationRadians(
            subEarthLatitudeDegrees: r.subEarthLatitudeDegrees,
            subEarthLongitudeDegrees: r.subEarthLongitudeDegrees)
        return MoonUniforms(
            sunDirection: sun,
            subEarthLat: lib.lat,
            subEarthLon: lib.lon,
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
            normalStrength: r.normalStrength,
            useBlueNoise: blueNoise != nil ? 1 : 0,
            targetSize: Float(pixelSize),
            retroEarthshine: r.retroEarthshine,
            retroBlackPoint: r.retroBlackPoint,
            cavityStrength: r.cavityStrength
        )
    }

    private func cgImage(from texture: MTLTexture, interpolate: Bool = true) throws -> CGImage {
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
                provider: provider, decode: nil, shouldInterpolate: interpolate,
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
    nonisolated init(readout: MoonReadout, style: DisplayStyle, ditherCell: Float = 1, ambient: Float = 0.015) {
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
