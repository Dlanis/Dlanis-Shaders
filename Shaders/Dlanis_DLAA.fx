// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#ifndef ONE_PASS_BLUR
    #define ONE_PASS_BLUR 0
#endif


#include "ReShadeUI.fxh"
#include "ReShade.fxh"

#include "Dlanis_Common_Minmax.fxh"
#include "Dlanis_Common_Colorspaces.fxh"


uniform int uRenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Edge\0Short Edge\0Short Edge Diagonal\0Long Edge\0Diagonal Long Edge\0Luma\0Blurred Luma\0Blur H\0Blur V\0Blur D\0Blur U\0Long Blur H\0Long Blur V\0Long Blur D\0Long Blur U\0";
> = 0;

uniform float uEdgeLambda <
  ui_label = "Edge Lambda";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 100.0; ui_step = 1.0;
//   ui_tooltip = "";
> = 20.0;

uniform float uEdgeEpsilon <
  ui_label = "Edge Epsilon";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 1.0;

uniform float uLongEdgeLambda <
  ui_label = "Long Edge Lambda";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 3.0;

uniform float uLongEdgeEpsilon <
  ui_label = "Long Edge Epsilon";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 1.3;

uniform float uLongEdgeDiagonalLambda <
  ui_label = "Long Edge Diagonal Lambda";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 3.0;

uniform float uLongEdgeDiagonalEpsilon <
  ui_label = "Long Edge Diagonal Epsilon";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 1.3;

uniform bool uSharpenLuma <
    ui_label = "Sharpen luma";
    ui_type = "radio";
//   ui_tooltip = "";
> = false;

uniform bool uPreserveHighFrequencies <
    ui_label = "Preserve High Frequencies";
    ui_type = "radio";
//   ui_tooltip = "";
> = false;

uniform float uHighMaskLambda <
  ui_label = "High Mask Lambda";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 5.0;

uniform float uHighMaskEpsilon <
  ui_label = "High Mask Epsilon";
  ui_type = "slider";
  ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
//   ui_tooltip = "";
> = 1.6;

uniform int uTest <
    ui_label = "Test";
    ui_type = "slider";
    ui_min = 0; ui_max = 1; ui_step = 1;
//   ui_tooltip = "";
> = 0;


texture tLuma <Pooled = true;> {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16F;};
#if ONE_PASS_BLUR <= 0
texture tBlurredLumaH <Pooled = true;> {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16F;};
#endif
texture tBlurredLuma <Pooled = true;> {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R16F;};
texture tEdge <Pooled = true;> {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG16F;};

sampler sLuma {Texture = tLuma;};
#if ONE_PASS_BLUR <= 0
sampler sBlurredLumaH {Texture = tBlurredLumaH;};
#endif
sampler sBlurredLuma {Texture = tBlurredLuma;};
sampler sEdge {Texture = tEdge;};


float LumaPS(float4 position : SV_Position, float2 texCoord : TEXCOORD) : SV_TARGET {
    // A   B
    //   S
    // D   C
    float S = Luma_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0)).rgb);
    float A = Luma_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord + float2(-0.5, -0.5)*BUFFER_PIXEL_SIZE, 0.0, 0.0)).rgb);
    float B = Luma_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord + float2( 0.5, -0.5)*BUFFER_PIXEL_SIZE, 0.0, 0.0)).rgb);
    float C = Luma_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord + float2( 0.5,  0.5)*BUFFER_PIXEL_SIZE, 0.0, 0.0)).rgb);
    float D = Luma_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord + float2(-0.5,  0.5)*BUFFER_PIXEL_SIZE, 0.0, 0.0)).rgb);

    if(uSharpenLuma == 1) {
        return S*9 - 2*A - 2*B - 2*C - 2*D;
    } else {
        return S;
    }
}

#if ONE_PASS_BLUR <= 0

float BlurLuma(sampler2D sam, float2 texCoord, float2 direction) {
    static const float offsets[2] = {0.0, 1.2};
    static const float weights[2] = {0.375, 0.3125};
    static const int width = 2;

    // static const float offsets[3] = {0.0, 1.3333333333333333, 3.111111111111111};
    // static const float weights[3] = {0.2734375, 0.328125, 0.03515625};
    // static const int width = 3;

    // static const float offsets[4] = {0.0, 1.3846153846153846, 3.230769230769231, 5.076923076923077};
    // static const float weights[4] = {0.2255859375, 0.314208984375, 0.06982421875, 0.003173828125};
    // static const int width = 4;

    float avg;
    [unroll]
    for(int i = 1-width; i < width; i++) {
        avg += weights[abs(i)]*tex2Dlod(sam, float4(texCoord + sign(i)*direction*offsets[abs(i)]*BUFFER_PIXEL_SIZE, 0.0, 0.0)).x;
    }

    return avg;
    // return tex2Dlod(sam, float4(texCoord, 0.0, 0.0));
}

float BlurLumaHPS(float4 position : SV_Position, float2 texCoord : TEXCOORD) : SV_TARGET {
    return BlurLuma(sLuma, texCoord, float2(1.0, 0.0));
}

float BlurLumaVPS(float4 position : SV_Position, float2 texCoord : TEXCOORD) : SV_TARGET {
    return BlurLuma(sBlurredLumaH, texCoord, float2(0.0, 1.0));
}

#else

float BlurLumaPS(float4 position : SV_Position, float2 texCoord : TEXCOORD) : SV_TARGET {
    static const float kernel[6] = {1,4,6,4,1,0};
    static const float weight = (1.0/256);

    float avg;
    [unroll]
    for(int i = 0; i < 6; i+=2) {
        [unroll]
        for(int j = 0; j < 6; j+=2) {
            float4 l = tex2DgatherR(sLuma, texCoord, int2(i, j) + int2(-2, -2));
            // w z
            // x y
            avg += l.w * weight * kernel[i+0]*kernel[j+0];
            avg += l.z * weight * kernel[i+1]*kernel[j+0];
            avg += l.x * weight * kernel[i+0]*kernel[j+1];
            avg += l.y * weight * kernel[i+1]*kernel[j+1];
        }
    }

    return avg;
}

#endif

float2 EdgePS(float4 position : SV_Position, float2 texCoord : TEXCOORD) : SV_TARGET {
    /*
    const int width = 6;
    float luma[36];
    [unroll]
    for(int i = 0; i < 6; i+=2) {
        [unroll]
        for(int j = 0; j < 6; j+=2) {
            float4 l = tex2DgatherR(sLuma, texCoord, int2(i, j) + int2(-2, -2));
            // w z
            // x y
            luma[(i+0) + (j+0)*width] = l.w;
            luma[(i+1) + (j+0)*width] = l.z;
            luma[(i+0) + (j+1)*width] = l.x;
            luma[(i+1) + (j+1)*width] = l.y;
        }
    }

    // Scharr 5x5
    static const float kernel[25] = {
        1, 1, 0, -1, -1,
        2, 2, 0, -2, -2,
        3, 6, 0, -6, -3,
        2, 2, 0, -2, -2,
        1, 1, 0, -1, -1,
    };
    static const float weight = (1.0/60.0);

    float2 Gradient;
    [unroll]
    for(int i = 0; i < 5; i++) {
        [unroll]
        for(int j = 0; j < 5; j++) {
            float l = luma[i + j*width];
            Gradient.x += l * (weight*kernel[i + j*5]);
            Gradient.y += l * (weight*kernel[j + i*5]);
        }
    }

    float Edge = length(Gradient);
    if(dot(Gradient, Gradient) > 1e-12) {
        Gradient /= MaxC(abs(Gradient));
    }

    return Gradient*clamp(Edge*uEdgeLambda*12.0 - uEdgeEpsilon*uEdgeEpsilon, 0.0, 1.0);
    // */

    // /*
    static const int width = 6;
    float blurredLuma[36];
    [unroll]
    for(int i = 0; i < 6; i+=2) {
        [unroll]
        for(int j = 0; j < 6; j+=2) {
            float4 l = tex2DgatherR(sBlurredLuma, texCoord, int2(i, j) + int2(-2, -2));
            // w z
            // x y
            blurredLuma[(i+0) + (j+0)*width] = l.w;
            blurredLuma[(i+1) + (j+0)*width] = l.z;
            blurredLuma[(i+0) + (j+1)*width] = l.x;
            blurredLuma[(i+1) + (j+1)*width] = l.y;
        }
    }

    float4 derivatives[4];
    {
        static const int2 offsets[4] = {
            int2( 0, -1), // North
            int2( 1,  0), // East
            int2( 0,  1), // South
            int2(-1,  0), // West
        };

        // Second order devativatives
        static const float kLxx[9] = {
            0, 0, 0,
            1,-2, 1,
            0, 0, 0,
        };
        static const float kLxy[9] = {
            ( 0.25),( 0.00),(-0.25),
            ( 0.00),( 0.00),( 0.00),
            (-0.25),( 0.00),( 0.25),
        };
        static const float kLyy[9] = {
            0, 1, 0,
            0,-2, 0,
            0, 1, 0,
        };

        [unroll]
        for(int k = 0; k < 4; k++) {
            int2 offset = offsets[k];

            float Lxx, Lxy, Lyy;
            [unroll]
            for(int i = 0; i < 3; i++) {
                [unroll]
                for(int j = 0; j < 3; j++) {
                    int2 pos = int2(i, j)+offset + int2(1,1);
                    float l = blurredLuma[pos.x + pos.y*width];
                    Lxx += l*kLxx[i + j*3];
                    Lxy += l*kLxy[i + j*3];
                    Lyy += l*kLyy[i + j*3];
                }
            }
            float center = blurredLuma[2+offset.x + (2+offset.y)*width];

            derivatives[k] = float4(Lxx, Lxy, Lyy, center);
        }
    }

    float4 North = derivatives[0];
    float4 East  = derivatives[1];
    float4 South = derivatives[2];
    float4 West  = derivatives[3];

    float Lx = East.w  - West.w;
    float Ly = South.w - North.w;
    float Lxxx = East.x  - West.x;
    float Lyyy = South.z - North.z;
    float Lxxy = East.y  - West.y;
    float Lxyy = South.y - North.y;

    float Edge = Lx*Lx*Lx*Lxxx + 3*Lx*Lx*Ly*Lxxy + 3*Lx*Ly*Ly*Lxyy + Ly*Ly*Ly*Lyyy;
    Edge = Max(-Edge, 0.0);

    float2 Direction = float2(Lx, Ly);
    if(dot(Direction, Direction) > 1e-12) {
        Direction /= MaxC(abs(Direction));
    }
    if(uSharpenLuma) {
        Edge *= 0.1;
    }
    return Direction*clamp(Edge*uEdgeLambda*100.0 - uEdgeEpsilon*uEdgeEpsilon, 0.0, 1.0);
    // */
}

float3 DLAAPS(float4 position : SV_Position, float2 texCoord : TEXCOORD) : SV_TARGET {
    float3 center = tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0)).rgb;
    float centerLuma = tex2Dlod(sLuma, float4(texCoord, 0.0, 0.0)).x;
    float centerBlurredLuma = tex2Dlod(sBlurredLuma, float4(texCoord, 0.0, 0.0)).x;
    float2 centerEdge = tex2Dlod(sEdge, float4(texCoord, 0.0, 0.0)).xy;
    float2 northEdge = tex2Dlod(sEdge, float4(texCoord, 0.0, 0.0), int2( 0, -1)).xy;
    float2 southEdge = tex2Dlod(sEdge, float4(texCoord, 0.0, 0.0), int2( 0,  1)).xy;
    float2 eastEdge = tex2Dlod(sEdge, float4(texCoord, 0.0, 0.0), int2( 1,  0)).xy;
    float2 westEdge = tex2Dlod(sEdge, float4(texCoord, 0.0, 0.0), int2(-1,  0)).xy;

    // | 0 | 1 | 2 | 3 |4| 5 | 6 | 7 | 8 |
    float4 H[9];
    {
        H[4] = float4(center, centerEdge.y);
        [unroll]
        for(int i = -4; i <= 4; i+=1) {
            if(i == 0) continue;

            float2 offset = float2(BUFFER_PIXEL_SIZE.x*(float(3*i-sign(i)) - 0.5*sign(i)), 0.0);
            H[i+4].rgb = tex2Dlod(ReShade::BackBuffer, float4(texCoord + offset, 0.0, 0.0)).rgb;
            float2 e = tex2Dlod(sEdge, float4(texCoord + offset, 0.0, 0.0)).xy;
            H[i+4].w = abs(e.y);
        }
    }
    float4 blurH = (H[3] + 0.5*H[4] + H[5]) * rcp(2.5);
    float4 longBlurH = (H[0] + H[1] + H[2] + H[3] + 0.5*H[4] + H[5] + H[6] + H[7] + H[8]) * rcp(8.5);
    blurH.w = Max(blurH.w, 0.0);
    longBlurH.w = Max(longBlurH.w, 0.0);

    float4 V[9];
    {
        V[4] = float4(center, centerEdge.x);
        [unroll]
        for(int i = -4; i <= 4; i+=1) {
            if(i == 0) continue;

            float2 offset = float2(0.0, BUFFER_PIXEL_SIZE.y*(float(3*i-sign(i)) - 0.5*sign(i)));
            V[i+4].rgb = tex2Dlod(ReShade::BackBuffer, float4(texCoord + offset, 0.0, 0.0)).rgb;
            float2 e = tex2Dlod(sEdge, float4(texCoord + offset, 0.0, 0.0)).xy;
            V[i+4].w = abs(e.x);
        }
    }
    float4 blurV = (V[3] + 0.5*V[4] + V[5]) * rcp(2.5);
    float4 longBlurV = (V[0] + V[1] + V[2] + V[3] + 0.5*V[4] + V[5] + V[6] + V[7] + V[8]) * rcp(8.5);
    blurV.w = Max(blurV.w, 0.0);
    longBlurV.w = Max(longBlurV.w, 0.0);

    float4 D[9];
    {
        D[4] = float4(center, Max(-centerEdge.x*centerEdge.y, 0.0));
        [unroll]
        for(int i = -4; i <= 4; i+=1) {
            if(i==0) continue;
            float2 offset = (float(2*i))*BUFFER_PIXEL_SIZE;
            D[i+4].rgb = tex2Dlod(ReShade::BackBuffer, float4(texCoord + offset, 0.0, 0.0)).rgb;
            float2 e = tex2Dlod(sEdge, float4(texCoord + offset, 0.0, 0.0)).xy;
            D[i+4].w = Max(-e.x*e.y, 0.0);
        }
    }
    float4 blurD = (D[3] + D[4] + D[5]) * rcp(3);
    float4 longBlurD = (D[0] + D[1] + D[2] + D[3] + D[4] + D[5] + D[6] + D[7] + D[8]) * rcp(9);

    float4 U[9];
    {
        U[4] = float4(center, Max(centerEdge.x*centerEdge.y, 0.0));
        [unroll]
        for(int i = -4; i <= 4; i+=1) {
            if(i==0) continue;
            float2 offset = float2(1.0, -1.0)*(float(2*i))*BUFFER_PIXEL_SIZE;
            U[i+4].rgb = tex2Dlod(ReShade::BackBuffer, float4(texCoord + offset, 0.0, 0.0)).rgb;
            float2 e = tex2Dlod(sEdge, float4(texCoord + offset, 0.0, 0.0)).xy;
            U[i+4].w = Max(e.x*e.y, 0.0);
        }
    }
    float4 blurU = (U[3] + U[4] + U[5]) * rcp(3);
    float4 longBlurU = (U[0] + U[1] + U[2] + U[3] + U[4] + U[5] + U[6] + U[7] + U[8]) * rcp(9);

    // direction *= float2(blurV.w, blurH.w)*2.0;
    // float2 shortEdge = SafeNormalize(direction) * Max(length(direction) * centerEdge * uEdgeLambda - uEdgeEpsilon*uEdgeEpsilon, 0.0);
    // float2 shortEdge = centerEdge.xy;
    // shortEdge /= MaxC(float3(abs(shortEdge), 1.0));

    float longEdgeH = clamp(longBlurH.w * uLongEdgeLambda - uLongEdgeEpsilon*uLongEdgeEpsilon, 0.0, 1.0);
    float longEdgeV = clamp(longBlurV.w * uLongEdgeLambda - uLongEdgeEpsilon*uLongEdgeEpsilon, 0.0, 1.0);
    float longEdgeD = clamp(longBlurD.w * uLongEdgeDiagonalLambda - uLongEdgeDiagonalEpsilon*uLongEdgeDiagonalEpsilon, 0.0, 1.0);
    float longEdgeU = clamp(longBlurU.w * uLongEdgeDiagonalLambda - uLongEdgeDiagonalEpsilon*uLongEdgeDiagonalEpsilon, 0.0, 1.0);

    float blurDWeight = Max(-centerEdge.x*centerEdge.y*blurD.w*1.5, 1e-6);
    float blurUWeight = Max( centerEdge.x*centerEdge.y*blurU.w*1.5, 1e-6);
    float diagonalWeight = blurDWeight + blurUWeight;
    float blurHWeight = Max(centerEdge.y*centerEdge.y*blurH.w*1.5 - diagonalWeight, 1e-6);
    float blurVWeight = Max(centerEdge.x*centerEdge.x*blurV.w*1.5 - diagonalWeight, 1e-6);

    float3 blurred = center;

    {
        blurred = lerp(blurred, blurH.rgb, blurHWeight);
        blurred = lerp(blurred, blurV.rgb, blurVWeight);
        blurred = lerp(blurred, blurU.rgb, blurUWeight);
        blurred = lerp(blurred, blurD.rgb, blurDWeight);

        //   N
        // W   E
        //   S

        float3 N = tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0, -1)).rgb;
        float3 S = tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0,  1)).rgb;

        float3 E = tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 1,  0)).rgb;
        float3 W = tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2(-1,  0)).rgb;

        float3 mn = Min3(Min3(N,S,E,W), center);
        float3 mx = Max3(Max3(N,S,E,W), center);

        blurred = clamp(blurred, mn, mx);

        float3 mnH = Min3(N,S,center);
        float3 mxH = Max3(N,S,center);
        float3 mnV = Min3(E,W,center);
        float3 mxV = Max3(E,W,center);

        blurred = lerp(blurred, clamp(longBlurH.rgb, mnH, mxH), longEdgeH);
        blurred = lerp(blurred, clamp(longBlurV.rgb, mnV, mxV), longEdgeV);
        blurred = lerp(blurred, clamp(longBlurD.rgb, mn, mx), longEdgeD);
        blurred = lerp(blurred, clamp(longBlurU.rgb, mn, mx), longEdgeU);

        if(uPreserveHighFrequencies) {
            float avg;
            [unroll]
            for(int i = -2; i <= 2; i++) {
                [unroll]
                for(int j = -2; j <= 2; j++) {
                    float2 offset = float2(
                        float(i*2) - 0.5*sign(i),
                        float(j*2) - 0.5*sign(j)
                    );
                    offset *= BUFFER_PIXEL_SIZE.xy;
                    float weight = Max(2.0*(i != 0) + 2.0*(j != 0), 1.0);
                    avg += weight * length(tex2Dlod(sEdge, float4(texCoord + offset, 0.0, 0.0)).xy);
                }
            }
            avg *= rcp(81.0);

            float highMask = saturate(avg*uHighMaskLambda - uHighMaskEpsilon*uHighMaskEpsilon);

            blurred = lerp(blurred, center, highMask);

            // Blurred = highMask * length(centerEdge);
        }
    }

    float3 o;
    switch(uRenderMode) {
        case 1:
            return float3(abs(centerEdge), 0.0);
        case 2:
            return float3(blurVWeight, blurHWeight, 0.0);
        case 3:
            return float3(blurDWeight, blurUWeight, 0.0);
        case 4:
            o = float3(longEdgeV, longEdgeH, 0.0);
            o.xy /= MaxC(float3(abs(o.xy), 1.0));
            return o;
        case 5:
            o = float3(longEdgeD, longEdgeU, 0.0);
            o.xy /= MaxC(float3(abs(o.xy), 1.0));
            return o;
        case 6:
            return centerLuma.x;
        case 7:
            return centerBlurredLuma.x;
        case 8:
            return blurH.rgb;
        case 9:
            return blurV.rgb;
        case 10:
            return blurD.rgb;
        case 11:
            return blurU.rgb;
        case 12:
            return longBlurH.rgb;
        case 13:
            return longBlurV.rgb;
        case 14:
            return longBlurD.rgb;
        case 15:
            return longBlurU.rgb;
        default:
            // if(uTest == 1 && length(centerEdge.xy) < 1e-3) {
            //     Blurred = center;
            // }

            return blurred;
    }
}


technique Dlanis_DLAA <
    ui_label = "Dlanis DLAA";
> {
    pass Luma
    {
        VertexShader = PostProcessVS;
        PixelShader = LumaPS;
        RenderTarget0 = tLuma;
    }
#if ONE_PASS_BLUR <= 0
    pass BlurLumaH {
        VertexShader = PostProcessVS;
        PixelShader = BlurLumaHPS;
        RenderTarget0 = tBlurredLumaH;
    }
    pass BlurLumaV {
        VertexShader = PostProcessVS;
        PixelShader = BlurLumaVPS;
        RenderTarget0 = tBlurredLuma;
    }
#else
    pass BlurLuma
    {
        VertexShader = PostProcessVS;
        PixelShader = BlurLumaPS;
        RenderTarget0 = tBlurredLuma;
    }
#endif
    pass Edge
    {
        VertexShader = PostProcessVS;
        PixelShader = EdgePS;
        RenderTarget0 = tEdge;
    }
    pass DLAA
    {
        VertexShader = PostProcessVS;
        PixelShader = DLAAPS;
    }
}
