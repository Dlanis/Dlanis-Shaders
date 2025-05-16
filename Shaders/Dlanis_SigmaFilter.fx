// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#include "ReShade.fxh"

#include "Dlanis_Common_Minmax.fxh"


uniform float uAmount <
  ui_label = "Amount";
  ui_type = "drag";
  ui_min = 0.001; ui_max = 1.0; ui_step = 0.001;
//   ui_tooltip = "";
> = 0.1;

uniform int uMinK <
  ui_label = "MinK";
  ui_type = "drag";
  ui_min = 0; ui_max = 24; ui_step = 1;
//   ui_tooltip = "";
> = 2;


float3 MainPS(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_TARGET {
    float3 c = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb;

    float4 avg;
    float4 bilat;
    int k;

    for(int i = -3; i <= 3; i++) {
        for(int j = -3; j <= 3; j++) {
            float3 s = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0), int2(i, j)).rgb;

            float diff = MaxC(abs(s - c));

            [flatten]
            if(diff < uAmount) {
                bilat += float4(s, 1.0);
                k++;
            }

            avg += s * rcp(49.0);
        }
    }

    [flatten]
    if(k > uMinK) {
        return bilat.rgb/(bilat.w+1e-9);
    } else {
        return avg;
    }
}


technique Dlanis_SigmaFilter <
    ui_label = "Dlanis Sigma Filter";
> {
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MainPS;
    }
}
