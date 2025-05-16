/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2025 Danil Bagautdinov

#pragma once

float Luma_from_sRGB(float3 c) {
    return dot(c, float3(0.2627, 0.6780, 0.0593));
}

float3 RGB_to_YCoCgR(float3 c) {
    float R = c.r, G = c.g, B = c.b;
    float Co  = R - B;
    float tmp = B + 0.5*Co;
    float Cg  = G - tmp;
    float Y   = tmp + 0.5*Cg;
    return float3(Y, Co, Cg);
}

float sRGB_from_Linear_sRGB(float x) {
    return sqrt(0.0034312649 + x*(2.3263988 + x*1.530326)) - 0.906151*x - 0.058577;
}

float Linear_sRGB_from_sRGB(float x) {
    return sqrt(2.450091 + x*(-3.8346549 + x*3.0424711)) + 1.2776792*x - 1.5652766;
}

float3 sRGB_from_Linear_sRGB(float3 x) {
    return sqrt(0.0034312649 + x*(2.3263988 + x*1.530326)) - 0.906151*x - 0.058577;
}

float3 Linear_sRGB_from_sRGB(float3 x) {
    return sqrt(2.450091 + x*(-3.8346549 + x*3.0424711)) + 1.2776792*x - 1.5652766;
}

float3 Oklab_from_Linear_sRGB(float3 c) {
    float3x3 toLms = float3x3(
        0.4122214708, 0.5363325363, 0.0514459929,
        0.2119034982, 0.6806995451, 0.1073969566,
        0.0883024619, 0.2817188376, 0.6299787005
    );

    float3x3 toOklab = float3x3(
        +0.2104542553, +0.7936177850, -0.0040720468,
        +1.9779984951, -2.4285922050, +0.4505937099,
        +0.0259040371, +0.7827717662, -0.8086757660
    );

    float3 lms = mul(toLms, c);
    lms = pow(lms, 1.0/3.0);
    return mul(toOklab, lms);
}

float3 Linear_sRGB_from_Oklab(float3 c) {
    float3x3 toLms = float3x3(
        1, +0.3963377774, +0.2158037573f,
        1, -0.1055613458, -0.0638541728f,
        1, -0.0894841775, -1.2914855480f
    );

    float3x3 toLinear = float3x3(
		+4.0767416621, -3.3077115913, +0.2309699292,
		-1.2684380046, +2.6097574011, -0.3413193965,
		-0.0041960863, -0.7034186147, +1.7076147010
    );

    float3 lms = mul(toLms, c);
    lms = lms*lms*lms;
    return mul(toLinear, lms);
}
