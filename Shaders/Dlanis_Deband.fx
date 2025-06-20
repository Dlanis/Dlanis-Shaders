/// SPDX-License-Identifier: MPL-2.0
/// Copyright 2024 Danil Bagautdinov

/// Deband shader by Dlanis

#include "ReShade.fxh"

#include "Dlanis_VkBasaltCompat.fxh"
#include "Dlanis_Common.fxh"
#include "Dlanis_BlueNoise.fxh"

#ifndef DIRECTIONS
    #define DIRECTIONS 1
#endif

/// FIXME: proper descriptions
/// Category Main
uniform uint MODE <
    ui_type = "combo";
    ui_label = "Mode";
    ui_items = "Disabled\0Dither\0Deband\0";
> = 2;

uniform uint COLOR_BIT_DEPTH_DETECTION <
    ui_type = "combo";
    ui_label = "Color Bit Depth";
    ui_items = "Manual\0Automatic\0";
> = 1;

uniform uint MANUAL_COLOR_BIT_DEPTH <
    ui_type = "slider";
    ui_label = "Manual Color Bit Depth";
    ui_min = 4;
    ui_max = 16;
> = BUFFER_COLOR_BIT_DEPTH;

/// Category Sky
uniform uint SKY_MODE <
    ui_category = "Sky";
    ui_type = "combo";
    ui_label = "Sky Mode";
    ui_items = "No sky masking\0Disabled\0Dither\0Deband\0";
> = 0;

uniform float SKY_COLOR_BIT_DEPTH <
    ui_category = "Sky";
    ui_type = "slider";
    ui_label = "Sky Color Bit Depth";
    ui_min = 4;
    ui_max = 16;
    ui_step = 0.1;
> = BUFFER_COLOR_BIT_DEPTH;

uniform float SKY_DEPTH <
    ui_category = "Sky";
    ui_type = "slider";
    ui_label = "Sky Depth";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 0.98;

/// Category Steps
uniform uint STEP_SIZE <
    ui_category = "Steps";
    ui_type = "slider";
    ui_label = "Step Size";
    ui_min = 2;
    ui_max = 256;
> = 8;

uniform uint STEPS <
    ui_category = "Steps";
    ui_type = "slider";
    ui_label = "Number of Steps";
    ui_min = 1;
    ui_max = 16;
> = 2;

/// Category Dither
uniform float DITHER_AMOUNT <
    ui_category = "Dither";
    ui_type = "slider";
    ui_label = "Dither Amount";
    ui_min = 0.0;
    ui_max = 8.0;
    ui_step = 0.1;
> = 1.0;

uniform bool ANIMATED_DITHER <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Animated dither";
> = true;

uniform bool COLORED_DITHER <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Colored Dither";
> = true;

uniform bool TRIANGULAR_DITHER <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Triangular Dither";
> = true;

uniform uint FRAMECOUNT < source = "framecount"; >;

float3 DebandPS(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
    float3 original = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb;

    bool is_sky = false;
    if(SKY_MODE != 0) {
        is_sky = ReShade::GetLinearizedDepth(texcoord) > SKY_DEPTH;
    }

    /// MODE/SKY_MODE = Disabled
    if((is_sky && SKY_MODE == 1) || (!is_sky && MODE == 0)) {
        return original;
    }

    float bit_depth;
    if(is_sky) {
        bit_depth = SKY_COLOR_BIT_DEPTH;
    } else {
        bit_depth = COLOR_BIT_DEPTH_DETECTION == 1 ? BUFFER_COLOR_BIT_DEPTH : MANUAL_COLOR_BIT_DEPTH;
    }
    float bit_size = rcp(exp2(bit_depth) - 1.0);

    uint dither_frame = ANIMATED_DITHER ? FRAMECOUNT : 0u;
    dither_frame *= 1u + DIRECTIONS;
    float3 color_dither;
    if(COLORED_DITHER) {
        color_dither = BlueNoise(vpos.xy, dither_frame).xyz;
    } else {
        color_dither = BlueNoise(vpos.xy, dither_frame).www;
    }

    if(TRIANGULAR_DITHER) {
        color_dither = TriangularizeNoise(color_dither)*2.0 - 0.5;
    } else {
        color_dither -= 0.5;
    }
    color_dither *= DITHER_AMOUNT * bit_size;

    if((is_sky && SKY_MODE == 2) || (!is_sky && MODE == 1)) {
        return original + color_dither;
    }

    float4 mean = float4(original * exp2(-32.0), exp2(-32.0));
    [unroll]
    for(uint i = 1; i <= DIRECTIONS; i++) {
        float2 dither = BlueNoise(vpos.xy, dither_frame + i).xy;

        float2 direction;
        sincos((dither.x + float(i)/float(DIRECTIONS)) * TAU, direction.x, direction.y);

        float3 last = original;
        [loop]
        for(uint i = 0; i < STEPS; i++) {
            float offset = float(i) + dither.y;

            float2 sample_position = texcoord + offset * direction * STEP_SIZE * BUFFER_PIXEL_SIZE;
            float3 scatter = tex2Dlod(ReShade::BackBuffer, float4(sample_position, 0.0, 0.0)).rgb;

            float4 diff = float4(abs(last - scatter), 0.0);
            diff.w = max(max(diff.r, diff.g), diff.b);

            float factor = float(diff.w < 1.5*bit_size);

            if(STEPS > 1) {
                if(factor < 0.01 || any(saturate(sample_position) != sample_position)) {
                    break;
                }
            }

            factor *= offset;

            last = lerp(last, scatter, factor);
            mean.rgb += scatter * factor;
            mean.w += factor;
        }
    }

    return mean.rgb * rcp(mean.w) + color_dither;
}

technique Dlanis_Deband <
    ui_tooltip = "Tries to hide color banding by searching gradients.";
> {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = DebandPS;
    }
}
