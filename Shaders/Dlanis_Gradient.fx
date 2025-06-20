// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#include "ReShade.fxh"

uniform float uScale = 2.0;
uniform uint uQuant = 64.0;


float3 GradientPS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_TARGET {
    float g;
    // g=texcoord.y;
    g=texcoord.x;
    // g=length(texcoord - float2(0.5,0.5));
    return floor(frac(g*uScale)*(uQuant+1))*rcp(uQuant);
}


technique Dlanis_Gradient <
    ui_label = "Dlanis Gradient";
> {
    pass Gradient
    {
        VertexShader = PostProcessVS;
        PixelShader = GradientPS;
    }
}
