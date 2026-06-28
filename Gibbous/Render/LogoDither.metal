//
//  LogoDither.metal
//  Gibbous
//
//  SwiftUI `colorEffect` entry points that run an arbitrary image (the Heirloom
//  "HL" mark on the retro settings screen) through the same 1-bit ordered dither
//  the retro moon uses, so it reads as a System-7-era graphic rather than a
//  glossy colour logo. See `retroDithered(scale:ink:paper:)` in SettingsPane.swift.
//
//  These live in their own translation unit, deliberately separate from
//  Moon.metal: SwiftUI resolves `[[stitchable]]` colour-effect functions through
//  its own visible-functions compilation, and keeping them out of the moon
//  shader's translation unit isolates them from that file's fragment shader and
//  file-scope state. The tiny `luma`/`bayer8` helpers are duplicated here (rather
//  than shared) so this file stands alone; Moon.metal keeps its own copies for
//  `moonFragment`.
//

#include <metal_stdlib>
using namespace metal;

// Rec. 601 luma — the perceptual weighting used for the retro dither.
static float logoLuma(float3 c) {
    return dot(c, float3(0.299, 0.587, 0.114));
}

// Ordered 8×8 Bayer threshold in (0, 1), for the 1-bit retro dither.
static float logoBayer8(uint2 c) {
    const float m[64] = {
         0, 32,  8, 40,  2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44,  4, 36, 14, 46,  6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
         3, 35, 11, 43,  1, 33,  9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47,  7, 39, 13, 45,  5, 37,
        63, 31, 55, 23, 61, 29, 53, 21,
    };
    return (m[(c.y % 8) * 8 + (c.x % 8)] + 0.5) / 64.0;
}

// Shared 1-bit dither for the colour-effect logo shaders below: the retro moon's
// tone curve, thresholded into ink/paper. Transparent pixels pass straight
// through so the glyph keeps its silhouette. The two stitchable entry points
// differ only in where `threshold` comes from (Bayer matrix vs blue-noise tile).
static half4 logoRetroDither(half4 color, float threshold, half4 ink, half4 paper) {
    if (color.a < 0.01h) { return color; }              // keep transparency outside the glyph
    float3 rgb = float3(color.rgb / max(color.a, 0.001h)); // un-premultiply before luma
    float lum = pow(saturate(logoLuma(rgb)), 0.85);     // same tone curve as the moon
    float bit = lum > threshold ? 1.0 : 0.0;
    half3 out = mix(ink.rgb, paper.rgb, half(bit));
    return half4(out * color.a, color.a);               // re-premultiply
}

// SwiftUI `colorEffect` entry point: run an arbitrary image through the same
// 1-bit ordered dither the retro moon uses. `scale` is the display scale (so
// dither cells lock to the device pixel grid), `cell` is the cell size in pixels,
// and `ink`/`paper` come from the retro palette.
[[ stitchable ]] half4 retroDitherLogo(float2 position, half4 color,
                                       float scale, float cell,
                                       half4 ink, half4 paper) {
    uint2 c = uint2(position * scale / max(1.0, cell));
    return logoRetroDither(color, logoBayer8(c), ink, paper);
}

// Blue-noise variant of the above — samples the same threshold tile the retro
// moon uses, for a finer, less mechanical stipple than the 8×8 Bayer matrix.
[[ stitchable ]] half4 retroDitherLogoBlue(float2 position, half4 color,
                                           float scale, float cell,
                                           half4 ink, half4 paper,
                                           texture2d<half> noise) {
    constexpr sampler noiseSampler(coord::normalized, address::repeat, filter::nearest);
    uint2 c = uint2(position * scale / max(1.0, cell));
    float tile = max(1.0, float(noise.get_width()));
    float threshold = float(noise.sample(noiseSampler, (float2(c) + 0.5) / tile).r);
    return logoRetroDither(color, threshold, ink, paper);
}
