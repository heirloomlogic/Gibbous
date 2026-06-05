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
};

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
                             texture2d<float> normalTex [[texture(1)]]) {
    constexpr sampler smp(coord::normalized, address::repeat,
                          filter::linear, mip_filter::linear);

    float2 p = in.uv * 2.0 - 1.0;   // centre the disc in [-1, 1]
    p.y = -p.y;                     // +y up
    float r2 = dot(p, p);
    if (r2 > 1.0) {
        return u.transparentOutside ? float4(0.0) : u.backgroundColor;
    }

    float z = sqrt(max(0.0, 1.0 - r2));
    float3 N = float3(p.x, p.y, z);             // geometric normal, unit length

    // Equirectangular lookup for the visible point (with libration).
    float3 Ns = applyLibration(N, u.subEarthLat, u.subEarthLon);
    float lat = asin(clamp(Ns.y, -1.0, 1.0));
    float lon = atan2(Ns.x, Ns.z);
    float2 texUV = float2(lon / (2.0 * M_PI_F) + 0.5, 0.5 - lat / M_PI_F);

    float3 albedo = albedoTex.sample(smp, texUV).rgb;

    // Tangent-space normal mapping for crater relief.
    float3 T = normalize(cross(float3(0.0, 1.0, 0.0), N));
    float3 B = cross(N, T);
    float3 tn = normalTex.sample(smp, texUV).rgb * 2.0 - 1.0;
    float3 Np = normalize(T * tn.x + B * tn.y + N * tn.z);

    float3 L = normalize(u.sunDirection);
    float ndl = max(dot(Np, L), 0.0);

    // Limb darkening: fade toward the limb (z → 0).
    float limb = mix(1.0, z, u.limbDarkening);
    float lit = ndl * limb + u.ambient;

    float3 color = albedo * lit;

    if (u.look == 1) {                       // black & white
        float lum = dot(color, float3(0.299, 0.587, 0.114));
        color = float3(lum);
    } else if (u.look == 2) {                // retro 1-bit ordered dither
        float lum = dot(color, float3(0.299, 0.587, 0.114));
        lum = pow(saturate(lum), u.retroGamma);
        float threshold = bayer8(uint2(in.position.xy / max(1.0, u.ditherCell)));
        float bit = lum > threshold ? 1.0 : 0.0;
        color = mix(u.retroDark.rgb, u.retroLight.rgb, bit);
    }

    return float4(color, 1.0);
}
