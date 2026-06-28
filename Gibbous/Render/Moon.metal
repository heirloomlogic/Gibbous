//
//  Moon.metal
//  Gibbous
//
//  Sphere-impostor moon. We draw a single full-screen triangle and, per
//  fragment, reconstruct the front hemisphere of a unit sphere. Each surface
//  point is mapped to (lat, lon) so the *equirectangular* albedo + normal maps
//  wrap correctly — no flat projection — and lit by a sun-direction uniform so
//  the phase terminator, limb darkening and crater relief all fall out of the
//  lighting equation. The visual spike uses MODERN (colour) only; B&W and the
//  1-bit dither looks are layered on later.
//

#include <metal_stdlib>
using namespace metal;

// Look modes — keep in sync with MoonLook in MoonRenderer.swift.
#define LOOK_BW    1
#define LOOK_RETRO 2

struct VOut {
    float4 position [[position]];
    float2 uv;
};

// Fullscreen triangle from vertex_id — no vertex buffer needed.
vertex VOut moonVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -3.0), float2(-1.0, 1.0), float2(3.0, 1.0) };
    float2 texcoords[3] = { float2(0.0, 2.0),   float2(0.0, 0.0),  float2(2.0, 0.0) };
    VOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = texcoords[vid];
    return out;
}

struct MoonUniforms {
    float3 sunDirection;     // unit, in view space (+z toward viewer)
    float subEarthLat;       // libration, radians
    float subEarthLon;       // libration, radians
    float limbDarkening;     // 0…1 strength
    float ambient;           // dark-side floor (earthshine hint)
    int look;                // 0 = modern colour, 1 = B&W, 2 = retro 1-bit
    int transparentOutside;  // 1 = alpha 0 outside the disc
    float ditherCell;        // retro: dither cell size in pixels
    float retroGamma;        // retro: tone curve before thresholding
    float4 backgroundColor;  // used when not transparent
    float4 retroDark;        // retro "ink"
    float4 retroLight;       // retro "paper"
    // Appended fields — keep this order identical to MoonUniforms in MoonRenderer.swift.
    float roll;              // disc roll (axis position angle), radians
    float surfaceBrightness; // albedo gain
    float surfaceContrast;   // albedo contrast around the lunar mean
    float normalStrength;    // crater relief emphasis
    int useBlueNoise;        // retro: 1 = blue-noise tile threshold, 0 = Bayer fallback
    float targetSize;        // render target dimension in pixels (for cell-centre shading)
    float retroEarthshine;   // retro: albedo wash that reveals highland in shadow
    float retroBlackPoint;   // retro: tones below this stay solid black (maria → no dither)
    float cavityStrength;    // crater self-shadow / ambient-occlusion emphasis
};

// Linear-space mean reflectance of the lunar disc — the pivot the surface
// contrast curve rotates around (so maria darken and highlands brighten rather
// than the whole disc crushing to black).
constant float kLunarMean = 0.12;

// Cavity falloff exponent: how sharply the ambient-occlusion term ramps in as the
// surface tilts away from the geometric normal. Higher keeps flats bright and
// confines the darkening to crater walls and rims.
constant float kCavity = 3.0;

// Half-width, in longitude, of the cropped equirectangular maps. The far side is
// never visible, so Moon.jpg / MoonNormal.jpg are cropped to the earth-facing
// ±105° band, and this MUST match that crop (a full-sphere map would be 180°). If
// the textures are re-exported with a different crop, update this to match or the
// limb will sample the wrong longitude.
constant float kLonHalfSpan = 105.0 * M_PI_F / 180.0;

// Rec. 601 luma — the perceptual weighting used for B&W and the retro dither.
static float luma(float3 c) {
    return dot(c, float3(0.299, 0.587, 0.114));
}

// Ordered 8×8 Bayer threshold in (0, 1), for the 1-bit retro dither.
static float bayer8(uint2 c) {
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

// The logo's `colorEffect` dither shaders live in LogoDither.metal — their own
// translation unit, so SwiftUI's stitchable compilation doesn't depend on this
// file's fragment shader or file-scope state.

// Rotate the surface normal so the sub-Earth point (libration) sits at the
// disc centre before we read it off the equirectangular maps.
static float3 applyLibration(float3 n, float lat, float lon) {
    float cl = cos(-lon), sl = sin(-lon);
    float3 r1 = float3(cl * n.x + sl * n.z, n.y, -sl * n.x + cl * n.z);
    float ca = cos(-lat), sa = sin(-lat);
    return float3(r1.x, ca * r1.y - sa * r1.z, sa * r1.y + ca * r1.z);
}

fragment float4 moonFragment(VOut in [[stage_in]],
                             constant MoonUniforms &u [[buffer(0)]],
                             texture2d<float> albedoTex [[texture(0)]],
                             texture2d<float> normalTex [[texture(1)]],
                             texture2d<float> blueNoiseTex [[texture(2)]]) {
    // clamp_to_edge: the maps are cropped to the earth-facing longitude band, so
    // longitude no longer wraps. Latitude never wrapped (poles sit at the edges).
    constexpr sampler smp(coord::normalized, address::clamp_to_edge,
                          filter::linear, mip_filter::linear);

    // Roll the whole picture by the axis position angle: sample the scene at the
    // de-rotated coordinate and rotate the light frame to match, so features,
    // terminator and limb darkening all turn together (phase fraction unchanged).
    float cr = cos(u.roll), sr = sin(u.roll);

    // The silhouette is evaluated *per pixel* so the limb stays round and
    // anti-aliased even when the retro dither quantises shading into chunky
    // cells (cell-resolution geometry alone gives a low-res circle a flat top
    // and sides). Feather the edge over ~1px against whatever sits behind it.
    float2 spPix = in.uv * 2.0 - 1.0;  // centre the disc in [-1, 1]
    spPix.y = -spPix.y;                // +y up
    float2 pPix = float2(cr * spPix.x + sr * spPix.y, -sr * spPix.x + cr * spPix.y);
    float rPix = length(pPix);
    float aa = max(fwidth(rPix), 1e-4);
    float coverage = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, rPix);
    if (coverage <= 0.0) {
        return u.transparentOutside ? float4(0.0) : u.backgroundColor;
    }

    // Shading sample point. Most looks shade per pixel and reuse the silhouette
    // point above. Retro instead snaps to the dither-cell centre so each chunky
    // cell resolves to a single shaded value — a faithful low-res 1-bit block —
    // while the silhouette keeps full resolution.
    float2 p = pPix;
    if (u.look == LOOK_RETRO) {
        float cell = max(1.0, u.ditherCell);
        float2 cellCentre = (floor(in.position.xy / cell) + 0.5) * cell;
        float2 sp = cellCentre / max(1.0, u.targetSize) * 2.0 - 1.0;
        sp.y = -sp.y;
        p = float2(cr * sp.x + sr * sp.y, -sr * sp.x + cr * sp.y);
    }

    float r2 = dot(p, p);
    float z = sqrt(max(0.0, 1.0 - r2));
    float3 N = float3(p.x, p.y, z);             // geometric normal, unit length

    // Equirectangular lookup for the visible point (with libration).
    float3 Ns = applyLibration(N, u.subEarthLat, u.subEarthLon);
    float lat = asin(clamp(Ns.y, -1.0, 1.0));
    float lon = atan2(Ns.x, Ns.z);
    // Longitude spans [−kLonHalfSpan, +kLonHalfSpan] across the cropped map's
    // width; clamp so the limb (just past the visible band at extreme libration)
    // samples the edge texel rather than wrapping.
    float u_x = clamp(lon / (2.0 * kLonHalfSpan) + 0.5, 0.0, 1.0);
    float2 texUV = float2(u_x, 0.5 - lat / M_PI_F);

    // Sharpen with a negative mip bias so maria/crater detail survives at the
    // small (96px) Modern disc, then push brightness/contrast so it reads.
    float3 albedo = albedoTex.sample(smp, texUV, bias(-0.5)).rgb;
    albedo = (albedo - kLunarMean) * u.surfaceContrast + kLunarMean;
    albedo = saturate(albedo * u.surfaceBrightness);

    // Tangent-space normal mapping for crater relief.
    float3 T = normalize(cross(float3(0.0, 1.0, 0.0), N));
    float3 B = cross(N, T);
    float3 tn = normalTex.sample(smp, texUV, bias(-0.5)).rgb * 2.0 - 1.0;
    tn.xy *= u.normalStrength;
    float3 Np = normalize(T * tn.x + B * tn.y + N * tn.z);

    // Cavity / ambient-occlusion proxy. Where the perturbed normal tilts away from
    // the geometric normal — crater walls, rims, rille edges — the surface is
    // partly self-shadowed no matter where the sun sits. Darkening by it makes the
    // relief read on the near-frontally-lit gibbous face, where direct N·L shading
    // alone washes crater detail out. Flats (Np ≈ N) stay fully lit.
    float cavity = pow(saturate(dot(Np, N)), kCavity);
    float ao = mix(1.0, cavity, u.cavityStrength);

    float3 L = normalize(u.sunDirection);
    L.xy = float2(cr * L.x - sr * L.y, sr * L.x + cr * L.y);  // rotate light with the disc
    float ndl = max(dot(Np, L), 0.0);

    // Limb darkening: fade toward the limb (z → 0).
    float limb = mix(1.0, z, u.limbDarkening);
    float lit = (ndl * limb + u.ambient) * ao;

    float3 color = albedo * lit;

    if (u.look == LOOK_BW) {                  // black & white
        color = float3(luma(color));
    } else if (u.look == LOOK_RETRO) {        // retro 1-bit blue-noise dither
        // Dither the moon's actual shaded luminance: that one continuous signal
        // carries the terminator, limb darkening, maria and crater relief, so
        // detail falls out for free. The gamma shapes the tone before threshold.
        float lum = pow(saturate(luma(color)), u.retroGamma);

        // Shadow-side differentiation. The dark side is filled by a faint
        // albedo-driven earthshine, so the brighter highland keeps a light
        // stipple while the darker maria reflect almost nothing. The black point
        // then crushes everything below it to solid black: the maria fall out of
        // the dither entirely (no dots), reading as their true dark shapes, while
        // the highland clears it. The lit crescent is unaffected (combined via
        // max, and its tones sit well above the black point).
        float albedoLum = luma(albedo);
        lum = max(lum, albedoLum * u.retroEarthshine);
        lum = saturate((lum - u.retroBlackPoint) / max(1e-3, 1.0 - u.retroBlackPoint));

        // One threshold per dither cell. Blue noise gives the grid-free, organic
        // stipple of the 1988 tools; Bayer is the fallback if the tile is absent.
        uint2 cell = uint2(in.position.xy / max(1.0, u.ditherCell));
        float threshold;
        if (u.useBlueNoise != 0) {
            uint w = blueNoiseTex.get_width();
            threshold = blueNoiseTex.read(uint2(cell.x % w, cell.y % w)).r;
        } else {
            threshold = bayer8(cell);
        }
        float bit = lum > threshold ? 1.0 : 0.0;
        color = mix(u.retroDark.rgb, u.retroLight.rgb, bit);
    }

    // Apply edge coverage: feather to transparent, or blend onto the background.
    // The readback treats the image as premultiplied, so premultiply here too.
    if (u.transparentOutside) {
        return float4(color * coverage, coverage);
    }
    return float4(mix(u.backgroundColor.rgb, color, coverage), 1.0);
}
