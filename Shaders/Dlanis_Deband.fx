/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2025 Danil Bagautdinov

/// Deband shader by Dlanis

#ifndef DIRECTIONS
    // Number of directions
    #define DIRECTIONS 1
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
    ui_min = 4;
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
    ui_min = 4;
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

/// Category Steps
uniform uint uSteps <
    ui_category = "Search";
    ui_type = "slider";
    ui_label = "Number of Steps";
    ui_min = 2;
    ui_max = 16;
> = 2;

uniform float uStepSize <
    ui_category = "Search";
    ui_type = "slider";
    ui_label = "Step Size";
    ui_min = 2;
    ui_max = 256;
    ui_step = 1;
> = 8;

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

    uint2 dither_pos = uint2(vpos.xy);
    if(uAnimatedDither) dither_pos += Hash1(uFrameCount).xy;
    uint dither_frame = 0;
    float3 color_dither;
    if(uColoredDither) {
        color_dither = BlueNoise(dither_pos, dither_frame++).xyz;
    } else {
        color_dither = BlueNoise(dither_pos, dither_frame++).www;
    }

    if(uTriangularDither) {
        color_dither = TriangularizeNoise(color_dither)*2.0 - 0.5;
    } else {
        color_dither -= 0.5;
    }
    color_dither *= uDitherAmount * bit_size;

    if((is_sky && uSkyMode == 2) || (!is_sky && uMode == 1)) {
        return original + color_dither;
    }

    float4 mean = float4(original * exp2(-32.0), exp2(-32.0));
    [unroll]
    for(uint i = 1; i <= DIRECTIONS; i++) {
        float2 dither = BlueNoise(dither_pos, dither_frame++).xy;

        float2 direction;
        sincos((dither.x + float(i)/float(DIRECTIONS)) * TAU, direction.x, direction.y);

        float3 last = original;
        [loop]
        for(uint i = 0; i < uSteps; i++) {
            float offset = float(i) + dither.y;

            float2 sample_position = texcoord + offset * direction * uStepSize * BUFFER_PIXEL_SIZE;
            float3 scatter = tex2Dlod(ReShade::BackBuffer, float4(sample_position, 0.0, 0.0)).rgb;

            float4 diff = float4(abs(last - scatter), 0.0);
            diff.w = MaxC(diff.rgb);

            float factor = float(diff.w < 1.5*bit_size);

            // if(uSteps > 1) {
                if(factor < 0.01 || any(saturate(sample_position) != sample_position)) {
                    break;
                }
            // }

            factor *= offset;

            last = lerp(last, scatter, factor);
            mean.rgb += scatter * factor;
            mean.w += factor;
        }
    }

    return mean.rgb * rcp(mean.w) + color_dither;
}

technique Dlanis_Deband <
    ui_label = "Dlanis Deband";
    ui_tooltip = "Tries to hide color banding by searching gradients.";
> {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = DebandPS;
    }
}
