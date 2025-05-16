// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#include "ReShade.fxh"

#include "Dlanis_Common_Colorspaces.fxh"


uniform float uAlpha <
    ui_label = "Alpha";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 5.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 1.0;

uniform float uBeta <
    ui_label = "Beta";
    ui_type = "drag";
    ui_min = -1.0; ui_max = 5.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 0.5;


float3 MainPS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_TARGET {
    float3 C = (tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb);
    C = Oklab_from_Linear_sRGB(Linear_sRGB_from_sRGB(C));
    // C.x = 2*C.x - pow(C.x, uAmount+1);
    float z = pow(C.x, uAlpha);
    C.x = ((uBeta + 1)*z)/(uBeta*z + 1);
    C = sRGB_from_Linear_sRGB(Linear_sRGB_from_Oklab(C));
    return C;
}


technique Dlanis_BrightnessAdjustment <
    ui_label = "Dlanis Brightness Adjustment";
> {
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MainPS;
    }
}
