// generate_blue_noise.swift
//
// Generates the void-and-cluster blue-noise tile used by the retro moon dither
// (Gibbous/Render/Moon.metal). Blue noise gives the grid-free, organic stipple
// of the 1988 Moon Tool / XMoonTool, where an ordered Bayer matrix reads as a
// mechanical screen.
//
// The algorithm is Ulichney's void-and-cluster (1993): build a sparse
// "prototype" binary pattern whose 1s are spread as evenly as possible (a
// minimum of clusters and voids), then rank every pixel by repeatedly removing
// the tightest cluster and filling the largest void. The resulting rank array,
// normalised to (0, 1), is a threshold map with blue-noise spectral properties.
//
// Deterministic (seeded), so the committed PNG is reproducible. Run:
//   swift Tools/generate_blue_noise.swift Gibbous/Resources/Textures/BlueNoise.png
//
// Output: a `dim`×`dim` 8-bit grayscale PNG (default 64×64), tiled at render time.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let dim = 64
let size = dim * dim
let sigma = 1.9  // Gaussian energy spread; ~1.5–2.0 is the usual blue-noise range.

// MARK: - Deterministic RNG (SplitMix64), so the tile is reproducible.

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
var rng = SplitMix64(seed: 0xB10E_4015_E)

// MARK: - Toroidal Gaussian energy field.

// Precompute exp(-d²/2σ²) by integer squared distance (toroidal max per axis is
// dim/2), so the energy updates are table lookups rather than exp() per pixel.
let maxDsq = 2 * (dim / 2) * (dim / 2)
let gauss: [Double] = (0...maxDsq).map { exp(-Double($0) / (2.0 * sigma * sigma)) }

var energy = [Double](repeating: 0, count: size)
var pattern = [Bool](repeating: false, count: size)

func wrapDelta(_ a: Int, _ b: Int) -> Int {
    let d = abs(a - b)
    return min(d, dim - d)
}

// Splat (or remove) one sample's Gaussian contribution across the whole tile.
func splat(_ index: Int, add: Bool) {
    let sx = index % dim
    let sy = index / dim
    for y in 0..<dim {
        let dy = wrapDelta(y, sy)
        let dy2 = dy * dy
        let row = y * dim
        for x in 0..<dim {
            let dx = wrapDelta(x, sx)
            let g = gauss[dx * dx + dy2]
            if add { energy[row + x] += g } else { energy[row + x] -= g }
        }
    }
}

func addSample(_ index: Int) {
    pattern[index] = true
    splat(index, add: true)
}
func removeSample(_ index: Int) {
    pattern[index] = false
    splat(index, add: false)
}

// Tightest cluster: the 1-pixel sitting in the densest neighbourhood (max energy).
func tightestCluster() -> Int {
    var best = -1
    var bestE = -Double.greatestFiniteMagnitude
    for i in 0..<size where pattern[i] && energy[i] > bestE {
        bestE = energy[i]
        best = i
    }
    return best
}

// Largest void: the 0-pixel sitting in the emptiest neighbourhood (min energy).
func largestVoid() -> Int {
    var best = -1
    var bestE = Double.greatestFiniteMagnitude
    for i in 0..<size where !pattern[i] && energy[i] < bestE {
        bestE = energy[i]
        best = i
    }
    return best
}

// MARK: - Initial prototype: ~10% ones, relaxed until clusters and voids settle.

let initialOnes = size / 10
do {
    var placed = 0
    while placed < initialOnes {
        let i = Int(rng.next() % UInt64(size))
        if !pattern[i] {
            addSample(i)
            placed += 1
        }
    }
    // Relax: move the tightest-clustered 1 into the largest void until stable.
    for _ in 0..<(size * 4) {
        let cluster = tightestCluster()
        removeSample(cluster)
        let void = largestVoid()
        if void == cluster {
            addSample(cluster)  // already optimal — done.
            break
        }
        addSample(void)
    }
}

// Snapshot the relaxed prototype so all three ranking phases start from it.
let prototype = pattern
let prototypeOnes = prototype.lazy.filter { $0 }.count

func restorePrototype() {
    for i in 0..<size { energy[i] = 0 }
    pattern = prototype
    for i in 0..<size where pattern[i] { splat(i, add: true) }
}

var rank = [Int](repeating: 0, count: size)

// Phase I — rank the prototype's 1s from sparse to dense by removing the
// tightest cluster each step (ranks prototypeOnes-1 … 0).
restorePrototype()
for r in stride(from: prototypeOnes - 1, through: 0, by: -1) {
    let i = tightestCluster()
    removeSample(i)
    rank[i] = r
}

// Phase II / III — fill every remaining 0 by repeatedly taking the largest void
// (ranks prototypeOnes … size-1), so the upper thresholds stay blue-noise too.
restorePrototype()
for r in prototypeOnes..<size {
    let i = largestVoid()
    addSample(i)
    rank[i] = r
}

// MARK: - Normalise ranks to 8-bit and write the PNG.

var bytes = [UInt8](repeating: 0, count: size)
for i in 0..<size {
    // (rank + 0.5) / size → centre of each threshold band, in (0, 1).
    let v = (Double(rank[i]) + 0.5) / Double(size)
    bytes[i] = UInt8(max(0, min(255, Int((v * 255.0).rounded()))))
}

let outPath =
    CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "BlueNoise.png"

guard let gray = CGColorSpace(name: CGColorSpace.linearGray),
    let ctx = CGContext(
        data: nil, width: dim, height: dim, bitsPerComponent: 8, bytesPerRow: dim,
        space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue),
    let buffer = ctx.data
else {
    FileHandle.standardError.write(Data("Failed to create grayscale context\n".utf8))
    exit(1)
}
buffer.copyMemory(from: bytes, byteCount: size)

guard let image = ctx.makeImage() else {
    FileHandle.standardError.write(Data("Failed to make image\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: outPath)
guard
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    FileHandle.standardError.write(Data("Failed to create PNG destination\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("Failed to write PNG\n".utf8))
    exit(1)
}
print("Wrote \(dim)×\(dim) blue-noise tile → \(outPath)")
