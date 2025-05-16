// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#pragma once

#define BLUENOISE_SIZE 128
#define BLUENOISE_DEPTH 32

texture tBlueNoiseRealUniformExp0101Seaparate05 < source = "Dlanis_BlueNoise_RealUniformBinomial3x3_Exp0101_Separate05.png"; > {
    Width  = BLUENOISE_SIZE*BLUENOISE_DEPTH;
    Height = BLUENOISE_SIZE;
    Format = R8;
};
sampler sBlueNoiseRealUniformExp0101Seaparate05 { Texture = tBlueNoiseRealUniformExp0101Seaparate05; };

texture tBlueNoiseRealUniformGauss10Seaparate05 < source = "Dlanis_BlueNoise_RealUniformBinomial3x3_Gauss10_Separate05.png"; > {
    Width  = BLUENOISE_SIZE*BLUENOISE_DEPTH;
    Height = BLUENOISE_SIZE;
    Format = R8;
};
sampler sBlueNoiseRealUniformGauss10Seaparate05 { Texture = tBlueNoiseRealUniformGauss10Seaparate05; };

float BlueNoise(sampler s, uint3 uv, uint n) {
    // g=1.22074408460575947536;
    // 1/g, 1/g^2, 1/g^3 scaled to nearest primes in 0-127, 0-127, 0-31 range
    // const uint3 phi3 = uint3(103, 83, 17);

    const uint2 phi2 = uint2(97, 73);
    return tex2Dfetch(s, ((uv.xy + n*phi2) & (BLUENOISE_SIZE-1)) + uint2(uv.z & (BLUENOISE_DEPTH-1), 0)*BLUENOISE_SIZE).r;
}

float BlueNoiseExp0101(uint3 uv, uint n) {
    return BlueNoise(sBlueNoiseRealUniformExp0101Seaparate05, uv, n);
}

float BlueNoiseGauss10(uint3 uv, uint n) {
    return BlueNoise(sBlueNoiseRealUniformGauss10Seaparate05, uv, n);
}

float3 BlueNoiseColorDither(uint2 pos, uint framecount, inout uint n, bool animated, bool colored) {
    uint3 dither_pos = uint3(pos, 0);
    if(animated) dither_pos.z = framecount;
    float3 dither;
    if(colored) {
        dither.r = BlueNoiseExp0101(dither_pos, n++).x;
        dither.g = BlueNoiseExp0101(dither_pos, n++).x;
        dither.b = BlueNoiseExp0101(dither_pos, n++).x;
    } else {
        dither = BlueNoiseExp0101(dither_pos, n++).xxx;
    }
    return dither;
}
