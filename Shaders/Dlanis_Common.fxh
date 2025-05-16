/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2025 Danil Bagautdinov

#pragma once

#define TAU 6.28318530717958647692
#define PI 3.14159265358979323846

// sign without zero handling
float SignNo0(float x) {
    return x < 0 ? -1 : 1;
}

float2 SafeNormalize(float2 v) {
    float sqrL = v.x*v.x + v.y*v.y;
    return v/sqrt(sqrL > 1e-12 ? sqrL : 1.0);
}

float ToFloat01(uint u) {
    return float(u) * (1.0 / 4294967296.0);
}

float2 ToFloat01(uint2 u) {
    return float2(ToFloat01(u.x), ToFloat01(u.y));
}

float3 ToFloat01(uint3 u) {
    return float3(ToFloat01(u.xy), ToFloat01(u.z));
}

float4 ToFloat01(uint4 u) {
    return float4(ToFloat01(u.xy), ToFloat01(u.zw));
}
