// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#include "ReShade.fxh"

#include "Dlanis_Common_Noise.fxh"
#include "Dlanis_Common_BlueNoise.fxh"


uniform float uAmount <
  ui_label = "Noise";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
//   ui_tooltip = "";
> = 0.1;

uniform float uMean <
  ui_label = "Mean";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
//   ui_tooltip = "";
> = 0.5;

uniform bool uAnimated <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Animated";
> = true;

uniform bool uColored <
    ui_category = "Dither";
    ui_type = "radio";
    ui_label = "Colored";
> = true;


uniform uint uFrameCount < source = "framecount"; >;


float3 DitherPS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_TARGET {
    float3 color = (tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb);
    // float3 dither = BlueNoise(uint2(position.xy) + Hash1(uFrameCount).xy, 0).rgb;
    float3 color_dither = BlueNoiseColorDither(vpos.xy, uFrameCount, 0, uAnimated, uColored);
    return (color + (dither - uMean) * uAmount);
}


technique Dlanis_Dither <
    ui_label = "Dlanis Dither";
> {
    pass Dither
    {
        VertexShader = PostProcessVS;
        PixelShader = DitherPS;
    }
}
