#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Smooth value noise for the crumple warp.
static float crumpleHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float crumpleNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(crumpleHash(i), crumpleHash(i + float2(1, 0)), u.x),
               mix(crumpleHash(i + float2(0, 1)), crumpleHash(i + float2(1, 1)), u.x), u.y);
}

static float crumpleFbm(float2 p) {
    return 0.65 * crumpleNoise(p) + 0.35 * crumpleNoise(p * 2.1 + 5.2);
}

/// Distorts a card like crushed paper.
/// - seed: per card, so every card crumples differently
/// - amount: 0 flat … 1 crumpled
/// - strength: the largest offset in points (about 5.5 % of the card width)
[[ stitchable ]] float2 crumple(float2 position, float seed, float amount, float strength) {
    float2 p = position / 30.0 + seed;
    float2 offset = float2(crumpleFbm(p), crumpleFbm(p + 17.0)) - 0.5;
    return position + offset * 2.0 * strength * amount;
}
