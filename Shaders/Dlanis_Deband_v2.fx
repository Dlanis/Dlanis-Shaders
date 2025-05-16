// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#ifndef DUAL_SEARCH
    #define DUAL_SEARCH 1
#endif


#include "ReShade.fxh"

#include "Dlanis_VkBasaltCompat.fxh"
#include "Dlanis_Common_Noise.fxh"
#include "Dlanis_Common_Minmax.fxh"
#include "Dlanis_Common_BlueNoise.fxh"


/// FIXME: proper descriptions
/// Category Main
uniform uint uMode <
    ui_type = "combo";
    ui_label = "Mode";
    ui_items = "Disabled\0Dither\0Deband\0";
> = 2;

uniform uint uColorBitDepthDetection <
    ui_type = "combo";
    ui_label = "Color Bit Depth";
    ui_items = "Manual\0Automatic\0";
> = 1;

uniform float uManualColorBitDepth <
    ui_type = "slider";
    ui_label = "Manual Color Bit Depth";
    ui_min = 1;
    ui_max = 16;
    ui_step = 0.1;
> = BUFFER_COLOR_BIT_DEPTH;

/// Category Sky
uniform uint uSkyMode <
    ui_category = "Sky";
    ui_type = "combo";
    ui_label = "Sky Mode";
    ui_items = "No sky masking\0Disabled\0Dither\0Deband\0";
> = 0;

uniform float uSkyColorBitDepth <
    ui_category = "Sky";
    ui_type = "slider";
    ui_label = "Sky Color Bit Depth";
    ui_min = 1;
    ui_max = 16;
    ui_step = 0.1;
> = BUFFER_COLOR_BIT_DEPTH;

uniform float uSkyDepth <
    ui_category = "Sky";
    ui_type = "slider";
    ui_label = "Sky Depth";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 0.98;

/// Category Search
uniform uint uDirections <
    ui_category = "Search";
    ui_type = "slider";
    ui_label = "Number of Directions";
    ui_min = 1;
    ui_max = 2;
> = 1;

uniform uint uSteps <
    ui_category = "Search";
    ui_type = "slider";
    ui_label = "Number of Steps";
    ui_min = 1;
    ui_max = 16;
> = 3;

uniform float uStepSize <
    ui_category = "Search";
    ui_type = "slider";
    ui_label = "Step Size";
    ui_min = 1;
    ui_max = 256;
    ui_step = 1;
> = 4;

/// Category Dither
uniform float uDitherAmount <
    ui_category = "Dither";
    ui_type = "slider";
    ui_label = "Dither Amount";
    ui_min = 0.0;
    ui_max = 8.0;
    ui_step = 0.1;
> = 1.0;

uniform bool uAnimatedDither <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Animated dither";
> = true;

uniform bool uColoredDither <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Colored Dither";
> = true;

uniform bool uTriangularDither <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Triangular Dither";
> = true;

// uniform bool uTest <
//     ui_category = "Test";
//     ui_type = "radio";
//     ui_label = "Test";
// > = true;

uniform uint uFrameCount < source = "framecount"; >;


float3 DebandPS(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
    float3 original = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb;

    bool is_sky = false;
    if(uSkyMode != 0) {
        is_sky = ReShade::GetLinearizedDepth(texcoord) > uSkyDepth;
    }

    /// uMode/uSkyMode = Disabled
    if((is_sky && uSkyMode == 1) || (!is_sky && uMode == 0)) {
        return original;
    }

    float bit_depth;
    if(is_sky) {
        bit_depth = uSkyColorBitDepth;
    } else {
        bit_depth = uColorBitDepthDetection == 1 ? BUFFER_COLOR_BIT_DEPTH : uManualColorBitDepth;
    }
    float bit_size = rcp(exp2(bit_depth) - 1.0);

    uint3 dither_pos = uint3(vpos.xy, 0);
    if(uAnimatedDither) dither_pos.z = uFrameCount;
    uint dither_frame = 0;

    // float3 color_dither;
    // if(uColoredDither) {
    //     color_dither.r = BlueNoiseExp0101(dither_pos, dither_frame++).x;
    //     color_dither.g = BlueNoiseExp0101(dither_pos, dither_frame++).x;
    //     color_dither.b = BlueNoiseExp0101(dither_pos, dither_frame++).x;
    // } else {
    //     color_dither = BlueNoiseExp0101(dither_pos, dither_frame++).xxx;
    // }

    float3 color_dither = BlueNoiseColorDither(vpos.xy, uFrameCount, dither_frame, uAnimatedDither, uColoredDither);

    if(uTriangularDither) {
        color_dither = TriangularizeNoise(color_dither)*2.0 - 0.5;
    } else {
        color_dither -= 0.5;
    }
    color_dither *= uDitherAmount * bit_size;

    if((is_sky && uSkyMode == 2) || (!is_sky && uMode == 1)) {
        return original + color_dither;
    }

    float2 offset_dither;
    float2 direction;

    float angle_dither = BlueNoiseExp0101(dither_pos, dither_frame++).x;
    offset_dither = BlueNoiseExp0101(dither_pos, dither_frame++).x;
    sincos(angle_dither*TAU, direction.x, direction.y);
    offset_dither.y = 1.0 - offset_dither.y;
    offset_dither = 1.0 - sqrt(1.0 - offset_dither);

    float4 mean[2];
    [loop]
    for(uint d = 0; d < uDirections; d++) {
        float offset = uStepSize;
        float size = uStepSize;
        float3 last[2] = {original, original};
        [loop]
        for(uint i = 0; i < uSteps; i++) {
            int2 s0_off = int2((offset - size*offset_dither.x) * direction);
            int2 s1_off = int2((offset - size*offset_dither.y) * direction);
            int2 s0_pos = clamp(int2(vpos.xy) + s0_off, 0, int2(BUFFER_WIDTH-1, BUFFER_HEIGHT-1));
            int2 s1_pos = clamp(int2(vpos.xy) - s1_off, 0, int2(BUFFER_WIDTH-1, BUFFER_HEIGHT-1));
            float3 s0 = tex2Dfetch(ReShade::BackBuffer, s0_pos);
            float3 s1 = tex2Dfetch(ReShade::BackBuffer, s1_pos);

            #if DUAL_SEARCH <= 0
                s1_pos = s0_pos;
                s1 = s0;
            #endif

            float2 diff;
            diff.x = MaxC(abs(s0 - last[0]));
            diff.y = MaxC(abs(s1 - last[1]));
            bool factor = MaxC(diff) <= bit_size;

            [flatten]
            if(factor) {
                float ww = size*sqrt(offset);
                last[0] = s0;
                last[1] = s1;
                mean[d].rgb += s0*ww + s1*ww;
                mean[d].w += 2*ww;
            }

            if(!factor) {
                break;
            }

            size += size;
            offset += size;
        }
        direction = float2(direction.y, -direction.x);
    }

    float4 choosen_mean;
    if(uDirections > 1) {
        choosen_mean = mean[0].w > mean[1].w ? mean[0] : mean[1];
    } else {
        choosen_mean = mean[0];
    }

    return (choosen_mean.w > 1e-6 ? (choosen_mean.rgb * rcp(choosen_mean.w)) : original) + color_dither;
}

technique Dlanis_Deband <
    ui_label = "Dlanis Deband v2";
    ui_tooltip = "Tries to hide color banding by searching gradients.";
> {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = DebandPS;
    }
}
