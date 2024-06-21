/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2024 Danil Bagautdinov

#define BLUENOISE_SIZE 128

texture tex_BlueNoise <
    source = "Dlanis_BlueNoise.png";
> {
    Width  = BLUENOISE_SIZE;
    Height = BLUENOISE_SIZE;
    Format = RGBA8;
};

sampler smp_BlueNoise {
    Texture = tex_BlueNoise;
    MagFilter = POINT;
    MinFilter = POINT;
    MipFilter = POINT;
    AddressU = WRAP;
    AddressV = WRAP;
};

float4 BlueNoise(uint2 uv, uint n) {
    const uint2 phi2 = uint2(3242174893u, 2447445397u);
    float2 offset = floor(ToFloat(n * phi2));
    return tex2D(smp_BlueNoise, (float2(uv) + 0.5)/BLUENOISE_SIZE.0 + offset).xyzw;
}
