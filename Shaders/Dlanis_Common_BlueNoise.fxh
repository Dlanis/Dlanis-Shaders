/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2025 Danil Bagautdinov

#pragma once

#define BLUENOISE_SIZE 128

texture tBlueNoise < source = "Dlanis_BlueNoise.png"; > {
    Width  = BLUENOISE_SIZE;
    Height = BLUENOISE_SIZE;
    Format = RGBA8;
};
sampler sBlueNoise { Texture = tBlueNoise; };

float4 BlueNoise(uint2 uv, uint n) {
    // (3242174888, 2447445413) scaled to nearest primes in 0-127 range
    const uint2 phi2 = uint2(97, 73);
    return tex2Dfetch(sBlueNoise, (uv + n*phi2) & 127);
}
