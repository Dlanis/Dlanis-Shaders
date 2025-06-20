/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2024 Danil Bagautdinov

#define TAU 6.28318530717958647692
#define PI 3.14159265358979323846

float ToFloat(uint u) {
    return float(u) * (1.0 / 4294967296.0);
}

float2 ToFloat(uint2 u) {
    return float2(ToFloat(u.x), ToFloat(u.y));
}

float3 ToFloat(uint3 u) {
    return float3(ToFloat(u.xy), ToFloat(u.z));
}

float4 ToFloat(uint4 u) {
    return float4(ToFloat(u.xy), ToFloat(u.zw));
}

/// XQO from https://github.com/skeeto/hash-prospector/issues/23
uint Hash(uint x) {
    x ^= x >> 14;
    x ^= 0xAAAAAAAAu;
    x = (x | 1u) ^ (x * x);
    x ^= x >> 14;
    x = (x | 1u) ^ (x * x);
    x ^= x >> 14;
    return x;
}

uint4 Hash4(uint4 x) {
    uint4 o;
    o.x = Hash(x.x ^ Hash(x.y ^ Hash(x.z ^ Hash(x.w))));
    o.y = Hash(o.x);
    o.z = Hash(o.y);
    o.w = Hash(o.z);
    return o;
}

uint4 Hash3(uint3 x) {
    uint4 o;
    o.x = Hash(x.x ^ Hash(x.y ^ Hash(x.z)));
    o.y = Hash(o.x);
    o.z = Hash(o.y);
    o.w = Hash(o.z);
    return o;
}

uint4 Hash2(uint2 x) {
    uint4 o;
    o.x = Hash(x.x ^ Hash(x.y));
    o.y = Hash(o.x);
    o.z = Hash(o.y);
    o.w = Hash(o.z);
    return o;
}

uint4 Hash1(uint x) {
    uint4 o;
    o.x = Hash(x);
    o.y = Hash(o.x);
    o.z = Hash(o.y);
    o.w = Hash(o.z);
    return o;
}

/// Based on Phi Noise 
/// Lincense: CC0 (https://creativecommons.org/publicdomain/zero/1.0)
/// https://www.shadertoy.com/view/wltSDn
uint PhiNoise(uint2 uv) {
    // flip every other tile to reduce anisotropy
    if(((uv.x ^ uv.y) & 4u) == 0u) uv = uv.yx;
    //if(((uv.x       ) & 4u) == 0u) uv.x = -uv.x;// more iso but also more low-freq content

    // constants of 2d Roberts sequence rounded to nearest primes
    const uint r0 = 3242174893u;// prime[(2^32-1) / phi_2  ]
    const uint r1 = 2447445397u;// prime[(2^32-1) / phi_2^2]

    // h = high-freq dither noise
    uint h = (uv.x * r0) + (uv.y * r1);

    // l = low-freq white noise
    uv = uv >> 2u;// 3u works equally well (I think)
    uint l = Hash2(uv).x;

    // combine low and high
    return l + h;
}

uint2 PhiNoise2(uint2 uv) {
    // flip every other tile to reduce anisotropy
    if(((uv.x ^ uv.y) & 4u) == 0u) uv = uv.yx;
    //if(((uv.x       ) & 4u) == 0u) uv.x = -uv.x;// more iso but also more low-freq content

    // constants of 2d Roberts sequence rounded to nearest primes
    const uint r0 = 3242174893u;// prime[(2^32-1) / phi_2  ]
    const uint r1 = 2447445397u;// prime[(2^32-1) / phi_2^2]

    // h = high-freq dither noise
    uint h = (uv.x * r0) + (uv.y * r1);

    // l = low-freq white noise
    uv = uv >> 2u;// 3u works equally well (I think)
    uint2 l = Hash2(uv).xy;

    // combine low and high
    return l + h;
}

uint3 PhiNoise3(uint2 uv) {
    // flip every other tile to reduce anisotropy
    if(((uv.x ^ uv.y) & 4u) == 0u) uv = uv.yx;
    //if(((uv.x       ) & 4u) == 0u) uv.x = -uv.x;// more iso but also more low-freq content

    // constants of 2d Roberts sequence rounded to nearest primes
    const uint r0 = 3242174893u;// prime[(2^32-1) / phi_2  ]
    const uint r1 = 2447445397u;// prime[(2^32-1) / phi_2^2]

    // h = high-freq dither noise
    uint h = (uv.x * r0) + (uv.y * r1);

    // l = low-freq white noise
    uv = uv >> 2u;// 3u works equally well (I think)
    uint3 l = Hash2(uv).xyz;

    // combine low and high
    return l + h;
}

uint4 PhiNoise4(uint2 uv) {
    // flip every other tile to reduce anisotropy
    if(((uv.x ^ uv.y) & 4u) == 0u) uv = uv.yx;
    //if(((uv.x       ) & 4u) == 0u) uv.x = -uv.x;// more iso but also more low-freq content

    // constants of 2d Roberts sequence rounded to nearest primes
    const uint r0 = 3242174893u;// prime[(2^32-1) / phi_2  ]
    const uint r1 = 2447445397u;// prime[(2^32-1) / phi_2^2]

    // h = high-freq dither noise
    uint h = (uv.x * r0) + (uv.y * r1);

    // l = low-freq white noise
    uv = uv >> 2u;// 3u works equally well (I think)
    uint4 l = Hash2(uv).xyzw;

    // combine low and high
    return l + h;
}

/// From somewhere
float TriangularizeNoise(float n) {
    n = 2.0*n - 1.0;
    n = sign(n) * (1.0 - sqrt(1.0 - abs(n)));
    return 0.5*n + 0.5;
}

float2 TriangularizeNoise(float2 n) {
    return float2(TriangularizeNoise(n.x), TriangularizeNoise(n.y));
}

float3 TriangularizeNoise(float3 n) {
    return float3(TriangularizeNoise(n.x), TriangularizeNoise(n.y), TriangularizeNoise(n.z));
}
