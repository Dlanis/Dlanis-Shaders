// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#ifndef RECOMPILE
    #define RECOMPILE 0
#endif

// #ifndef EDGE_BOOSTING
//     #define EDGE_BOOSTING 0
// #endif

// #ifndef OKLAB_EDGE_DETECTION
//     #define OKLAB_EDGE_DETECTION 0
// #endif


#include "ReShade.fxh"

#include "Dlanis_Common.fxh"
#include "Dlanis_Common_Colorspaces.fxh"
#include "Dlanis_Common_Minmax.fxh"


uniform uint uRenderMode <
    ui_label = "Render Mode";
    ui_type = "combo";
    ui_items = "Image\0Edge\0Blend Weights\0";
> = 0;

uniform float uEdgeThreshold <
    ui_label = "Edge Threshold";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.1;

uniform float uContrastThreshold <
    ui_label = "Contrast Threshold";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.5;

uniform float uLambda <
    ui_label = "Lambda";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
> = 1.0;

uniform int uTestRender <
    ui_label = "Test Render";
    ui_type = "slider";
    ui_min = 0; ui_max = 10; ui_step = 1;
> = 0;

uniform int uTest <
    ui_label = "Test";
    ui_type = "slider";
    ui_min = 0; ui_max = 10; ui_step = 1;
> = 0;


namespace Dlanis_AA2 {

texture tRawEdge < pooled = false; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG8; };
sampler sRawEdge { Texture = tRawEdge; };

texture tEdge < pooled = false; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RG8; };
sampler sEdge { Texture = tEdge; };

texture tBlendWeights < pooled = false; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler sBlendWeights { Texture = tBlendWeights; };


#if 0

float ColorDifferenceSquared(float3 a, float3 b) {
    float rm = 0.5*a.r + 0.5*b.r;
    float3 d = a - b;
    return (2 + rm)*d.r*d.r + 4*d.g*d.g + (3 - rm)*d.b*d.b;
}

float ColorDifference(float3 a, float3 b) {
    // return (ColorDifferenceSquared(a, b));
    return MaxC(abs(a - b));
}

// float ColorDifferenceOklab(float3 a, float3 b) {
//     float3 a_ = Oklab_from_Linear_sRGB(Linear_sRGB_from_sRGB(a));
//     float3 b_ = Oklab_from_Linear_sRGB(Linear_sRGB_from_sRGB(b));
//
//     return length(a_ - b_);
// }

float2 EdgeDetectionPS(in float4 position : SV_Position, in float2 texCoord : TEXCOORD) : SV_Target {
    //      NN
    //      N
    // WW W C E
    //      S
    // float3 C  = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0,  0)).rgb);
    // float3 N  = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0, -1)).rgb);
    // float3 NN = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0, -2)).rgb);
    // float3 E  = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 1,  0)).rgb);
    // float3 S  = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0,  1)).rgb);
    // float3 W  = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2(-1,  0)).rgb);
    // float3 WW = RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2(-2,  0)).rgb);

    // float gEC = dot(abs(E - C), float3(2,1,1));
    // float gCW = dot(abs(C - W), float3(2,1,1));
    // float gWWW = dot(abs(W - WW), float3(2,1,1));

    // gCW = gCW * float(gCW > float(uContrastThreshold)*Max3(gEC, gCW, gWWW));

    // float gSC = dot(abs(S - C), float3(2,1,1));
    // float gCN = dot(abs(C - N), float3(2,1,1));
    // float gNNN = dot(abs(N - NN), float3(2,1,1));

    // gCN = gCN * float(gCN > float(uContrastThreshold)*Max3(gSC, gCN, gNNN));

    // return float2(gCW, gCN);

    float3 color[16];

    [unroll]
    for(int i = 0; i < 4; i+=2) {
        [unroll]
        for(int j = 0; j < 4; j+=2) {
            float2 offset = (float2(i, j) - 2.0 + 0.5)*BUFFER_PIXEL_SIZE;

            // w z
            // x y
            float4 R = tex2DgatherR(ReShade::BackBuffer, texCoord + offset).xyzw;
            float4 G = tex2DgatherG(ReShade::BackBuffer, texCoord + offset).xyzw;
            float4 B = tex2DgatherB(ReShade::BackBuffer, texCoord + offset).xyzw;

            color[(i+0) + (j+0)*4].r = R.w;
            color[(i+1) + (j+0)*4].r = R.z;
            color[(i+0) + (j+1)*4].r = R.x;
            color[(i+1) + (j+1)*4].r = R.y;

            color[(i+0) + (j+0)*4].g = G.w;
            color[(i+1) + (j+0)*4].g = G.z;
            color[(i+0) + (j+1)*4].g = G.x;
            color[(i+1) + (j+1)*4].g = G.y;

            color[(i+0) + (j+0)*4].b = B.w;
            color[(i+1) + (j+0)*4].b = B.z;
            color[(i+0) + (j+1)*4].b = B.x;
            color[(i+1) + (j+1)*4].b = B.y;
        }
    }

    float Hmx, Vmx;

    float2 g[9];
    [unroll]
    for(int i = 0; i < 3; i++) {
        [unroll]
        for(int j = 0; j < 3; j++) {
            // float3 C = RGB_to_YCoCgR(color[(i+1) + (j+1)*4]);
            // float3 N = RGB_to_YCoCgR(color[(i+1) + (j+0)*4]);
            // float3 W = RGB_to_YCoCgR(color[(i+0) + (j+1)*4]);
            // float H = dot(abs(C - N), float3(2,1,1));
            // float V = dot(abs(C - W), float3(2,1,1));
            // float H = MaxC(abs(C - N) * float3(1,1,1));
            // float V = MaxC(abs(C - W) * float3(1,1,1));

            float3 C = (color[(i+1) + (j+1)*4]);
            float3 N = (color[(i+1) + (j+0)*4]);
            float3 W = (color[(i+0) + (j+1)*4]);
            float H = ColorDifference(C, N);
            float V = ColorDifference(C, W);

            // if(j == 1)
                Hmx = Max(Hmx, H);
            // if(i == 1)
                Vmx = Max(Vmx, V);
            g[(i) + (j)*3].x = H;
            g[(i) + (j)*3].y = V;
        }
    }

    float2 gC = g[(1) + (1)*3];

    // if(uTest == 1) {
    //     float2 Hmn = float2(g[(1) + (0)*3].x, g[(1) + (2)*3].x);
    //     float2 Vmn = float2(g[(0) + (1)*3].y, g[(2) + (1)*3].y);
    //     gC.x = gC.x - MinC(Hmn * (Hmn < gC.x));
    //     gC.y = gC.y - MinC(Vmn * (Vmn < gC.y));
    // } else {
        gC.x *= gC.x > uContrastThreshold*Hmx;
        gC.y *= gC.y > uContrastThreshold*Vmx;
    // }

    bool2 edge = bool2(gC.x > uEdgeThreshold, gC.y > uEdgeThreshold);

//     if(uRenderMode == 1) {
//         return gC * float2(gC > uEdgeThreshold);
//     } else {
        return edge;
//     }
}

#else

float2 EdgeDetectionPS(in float4 position : SV_Position, in float2 texCoord : TEXCOORD) : SV_Target {
    int2 pos = int2(position.xy);

    float3 C = Oklab_from_Linear_sRGB(Linear_sRGB_from_sRGB(tex2Dfetch(ReShade::BackBuffer, pos + int2( 0,  0)).rgb));
    float3 N = Oklab_from_Linear_sRGB(Linear_sRGB_from_sRGB(tex2Dfetch(ReShade::BackBuffer, pos + int2( 0, -1)).rgb));
    float3 W = Oklab_from_Linear_sRGB(Linear_sRGB_from_sRGB(tex2Dfetch(ReShade::BackBuffer, pos + int2(-1,  0)).rgb));

    return float2(
        pos.y > 0 ? length(C - N) : 0,
        pos.x > 0 ? length(C - W) : 0
    );
    // return float2(
    //     pos.y > 0 ? (length(C.yz - N.yz) + abs(C.x - N.x)) : 0,
    //     pos.x > 0 ? (length(C.yz - W.yz) + abs(C.x - W.x)) : 0
    // );
}

float2 EdgeFilterPS(in float4 position : SV_Position) : SV_Target {
    int2 pos = int2(position.xy);

    float2 C = tex2Dfetch(sRawEdge, pos + int2( 0, 0)).rg;
    float2 N = tex2Dfetch(sRawEdge, pos + int2( 0,-1)).rg;
    float2 S = tex2Dfetch(sRawEdge, pos + int2( 0, 1)).rg;
    float2 W = tex2Dfetch(sRawEdge, pos + int2(-1, 0)).rg;
    float2 E = tex2Dfetch(sRawEdge, pos + int2( 1, 0)).rg;

    float maxH = Max(C.x, N.x, S.x);
    float maxV = Max(C.y, W.y, E.y);

    return (C > uEdgeThreshold) && (C > uContrastThreshold*float2(maxH, maxV));
}

#endif

/*
float2 EdgeBoostingPS(in float4 position : SV_Position, in float2 texCoord : TEXCOORD) : SV_Target {
    float2 C = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0)).xy;

    float H0 = C.x;
    float H1 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2( 1, 0)).x;
    float H2 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2( 2, 0)).x;
    float H3 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2(-1, 0)).x;
    float H4 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2(-2, 0)).x;

    float V0 = C.y;
    float V1 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2(0,  1)).y;
    float V2 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2(0,  2)).y;
    float V3 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2(0, -1)).y;
    float V4 = tex2Dlod(sRawEdge, float4(texCoord, 0.0, 0.0), int2(0, -2)).y;

    float Hmx = Max5(H0, H1, H2, H3, H4);
    // bool Hwr = (H1 > (0.5 * Hmx)) && (H2 > (0.5 * Hmx));
    // bool Hwl = (H3 > (0.5 * Hmx)) && (H4 > (0.5 * Hmx));
    // bool Hw0 = (H0 > (0.5 * Hmx));
    // bool Hw = (Hwr && Hwl) || (Hwr && Hw0) || (Hw0 && Hwl);

    float Vmx = Max5(V0, V1, V2, V3, V4);
    // bool Vwd = (V1 > (0.5 * Vmx)) && (V2 > (0.5 * Vmx));
    // bool Vwu = (V3 > (0.5 * Vmx)) && (V4 > (0.5 * Vmx));
    // bool Vw0 = (V0 > (0.5 * Vmx));
    // bool Vw = (Vwd && Vwu) || (Vwd && Vw0) || (Vw0 && Vwu);

    if(bool(EDGE_BOOSTING)) {
        // C.y += Hmx * Hw + H0 * (!Vw0 && (Vwd ^ Vwu) && (Hwl + Hwr <= 1));
        // C.x += Vmx * Vw + V0 * (!Hw0 && (Hwr ^ Hwl) && (Vwd + Vwu <= 1));

        C.y *= V0 > 0.50 * Vmx;
        C.x *= H0 > 0.50 * Hmx;
    }

    return C;
}
// */

float LineX(float2 a, float2 b, float y) {
    return (b.x - a.x)*(y - a.y)/(b.y - a.y) + a.x;
}

float LineY(float2 a, float2 b, float x) {
    return (b.y - a.y)*(x - a.x)/(b.x - a.x) + a.y;
}

float4 EdgeWeightsCalculationPS(in float4 position : SV_Position) : SV_Target {
    int2 pos = position.xy;

    const int maxSearchLength = 64;

#if 0

    int2 C;
    /// C.x YUpRight
    /// C.y YDownLeft
    {
        int i, lasti = 1, j;
        while(i > -maxSearchLength) {
            float2 edge = tex2Dfetch(sEdge, pos + int2(j, i)).xy;
            if(edge.y < 0.9) {
                break;
            }
            if(edge.x > 0.9) {
                float2 edgeNE = tex2Dfetch(sEdge, pos + int2(j+1, i-1)).xy;
                if(edgeNE.y > 0.9) {
                    lasti = i;
                }
            }
            i--;
        }
        /// store dead end as a positive
        C.x = lasti < 1 ? lasti-1 : -i;
    }
    {
        int i, lasti = -1, j;
        while(i < maxSearchLength) {
            float2 edge = tex2Dfetch(sEdge, pos + int2(j, i)).xy;
            if(edge.y < 0.9) {
                break;
            }
            float2 edgeSW = tex2Dfetch(sEdge, pos + int2(j-1, i+1)).xy;
            if(edgeSW.x > 0.9 && edgeSW.y > 0.9) {
                lasti = i;
            }
            i++;
        }
        /// store dead end as a negative
        C.y = lasti > -1 ? lasti+1 : -i;
    }
    if(C.x == 0 || C.y == 0) discard;
    float2 U;
    {
        U.y = -abs(C.x);
        U.x = C.x < 0 ? 0.5 : 0;
    }
    if(false)
    {
        if(C.x > 0) {
            U.y = -C.x;
        } else {
            const int centralVLength = abs(C.y)+abs(C.x)-1;
            int i, lasti = 1, j, deviation, currentLength;
            i = C.x;
            j = 1;
            while(i > -maxSearchLength) {
                float2 edge = tex2Dfetch(sEdge, pos + int2(j, i)).xy;
                int currentDeviation = currentLength - centralVLength;
                if(edge.y < 0.9 || currentDeviation > 1) {
                    // TODO: better deviation
                    deviation += abs(currentDeviation) > 0;
                    if(currentDeviation < -1) {
                        // i -= -currentDeviation+1;
                        break;
                    }
                    if(lasti < 1 && deviation < 3) {
                        i = lasti+1;
                        j++;
                        lasti = 1;
                        currentLength = -1;
                    } else {
                        break;
                    }
                } else {
                    if(edge.x > 0.9) {
                        float2 edgeNE = tex2Dfetch(sEdge, pos + int2(j+1, i-1)).xy;
                        if(edgeNE.y > 0.9) {
                            lasti = i;
                        }
                    }
                }
                currentLength++;
                i--;
            }
            [flatten]
            if(lasti < 1) {
                U.y = lasti-1;
            } else {
                U.y = i;
            }
            U.x = j - 1;

            // U.y = -U.y + centralVLength;
            // U.y = centralVLength;
        }
    }
    float2 D;
    {
        D.y = abs(C.y);
        D.x = C.y > 0 ? -0.5 : 0;
    }

#elif 0

    float2 U, D;
    float C;
    float ui, uj, uli, ud, ul;
    float di, dj, dli, dd, dl;
    bool udone, ddone;

    while(ui < maxSearchLength && di < maxSearchLength) {
        if(!udone) {
            float2 edge = tex2Dfetch(sEdge, pos + int2(uj, -ui)).xy;
            float2 edgeNE = tex2Dfetch(sEdge, pos + int2(uj, -ui) + int2(1, -1)).xy;

            float cd = (ul - C + 1) * (uj != 0);
            if(edge.y && cd < 1.5) {
                if(edge.x && edgeNE.y) {
                    U = float2(uj, -ui);
                    uli = ui+1;
                }
                C += (uj==0);
                ui++;
                ul++;
            } else {
                if(uli && cd > -1.5) {
                    // if(SignNo0(ud) != SignNo0(cd) || cd < -1.5) {
                    //     break;
                    // }
                    ud += cd;

                    ui = uli;
                    uj++;
                    uli = 0;
                    ul = 0;
                } else {
                    break;
                }
            }
        }
        if(!ddone) {
            float2 edge = tex2Dfetch(sEdge, pos + int2(-dj, di)).xy;
            float2 edgeSW = tex2Dfetch(sEdge, pos + int2(-dj, di) + int2(-1, 1)).xy;

            float cd = (dl - C + 1) * (uj != 0);
            if(edge.y && cd < 1.5) {
                if(edgeSW.x && edgeSW.y) {
                    D = float2(-dj, di);
                    dli = di+1;
                }
                C += (dj==0);
                di++;
                dl++;
            } else {
                if(dli && cd > -1.5) {
                    // if(SignNo0(dd) != SignNo0(cd) || cd < -1.5) {
                    //     break;
                    // }
                    dd += cd;

                    di = dli;
                    dj++;
                    dli = 0;
                    dl = 0;
                } else {
                    break;
                }
            }
        }
    }

#elif 1

    float2 U, D;
    float C;
    float ud, dd, j, ui, di;

    while(j < 3) {
        float ul, dl;
        {
            float i = ui, li;
            float2 edge = tex2Dfetch(sEdge, pos + int2(j, -i)).xy, edgeNE;
            while(i < maxSearchLength && edge.y > 0.9 && (i-ui-C < 1.5 || j == 0)) {
                edgeNE = tex2Dfetch(sEdge, pos + int2(j, -i) + int2(1, -1)).xy;

                li = (edge.x > 0.9 && edgeNE.y > 0.9) ? i+1 : li;
                i++;

                edge = tex2Dfetch(sEdge, pos + int2(j, -i)).xy;
            }

            ul = (li > 0) ? ui-li : i-ui;
            ui = (li > 0) ? li : i;
        }
        {
            float i = di, li;
            float2 edge = tex2Dfetch(sEdge, pos + int2(-j, i)).xy, edgeSW;
            while(i < maxSearchLength && edge.y > 0.9 && (i-di-C < 1.5 || j == 0)) {
                edgeSW = tex2Dfetch(sEdge, pos + int2(-j, i) + int2(-1, 1)).xy;

                li = (edgeSW.x > 0.9 && edgeSW.y > 0.9) ? i+1 : li;
                i++;

                edge = tex2Dfetch(sEdge, pos + int2(-j, i)).xy;
            }

            dl = (li > 0) ? di-li : i-di;
            di = (li > 0) ? li : i;
        }
        C = (j == 0) ? abs(ul)+abs(dl)-1 : C;

        [flatten]
        if(j != 0) {
            float ulc = abs(ul)-C;
            float dlc = abs(dl)-C;
            float sud = clamp(ud, -1, 1);
            float sdd = clamp(dd, -1, 1);

            if(false
               || ul == 0
               || dl == 0
               || abs(ulc) > 1.5
               || abs(dlc) > 1.5
            //    || abs(ulc - sud) > 1.5
            //    || abs(dlc - sdd) > 1.5
            //    || abs(sud - sdd) > 1.5
            //    || abs(ud-dd) > 2.5
               ) {
                break;
            }

            ud += ulc;
            dd += dlc;
        }

        U.y = -ui+1;
        //U.x = j + (ul < 0 ? 0.5 : 0);
        U.x = j;

        D.y = di-1;
        //D.x = -(j + (dl < 0 ? 0.5 : 0));
        D.x = -j;

        j++;
    }

#else

    float2 U;
    {
        int i, j;
        while(i < maxSearchLength && j < 8) {
            float2 edge = tex2Dfetch(sEdge, pos + int2(j, -i)).xy;
            if(edge.y < 0.9) {
                float2 southEdge = tex2Dfetch(sEdge, pos + int2(j, -i+1)).xy;
                float2 eastEdge = tex2Dfetch(sEdge, pos + int2(j+1, -i)).xy;

                if(southEdge.x > 0.9 && eastEdge.y > 0.9) {
                    j++;
                } else {
                    break;
                }
            } else {
                U = float2(j, -i);
            }
            i++;
        }
    }

    float2 D;
    {
        int i, j;
        while(i < maxSearchLength && j < 8) {
            float2 edge = tex2Dfetch(sEdge, pos + int2(-j, i)).xy;
            if(edge.y < 0.9) {
                float2 westEdge = tex2Dfetch(sEdge, pos + int2(-j-1, i)).xy;

                if(westEdge.x > 0.9 && westEdge.y > 0.9) {
                    j++;
                } else {
                    break;
                }
            } else {
                D = float2(-j, i);
            }
            i++;
        }
    }

#endif

    float4 weights;
    if(U.x - D.x > 0.1) {
        // U.y += 0.5;
        // D.y -= 0.5;
        float y0 = LineY(D, U, 0);
        if(-0.5 < y0 && y0 < 0.5) {
            weights.x = -(-0.5-y0)*LineX(D, U, -0.5);
            weights.y = -(0.5-y0)*LineX(D, U, 0.5);
        } else {
            weights.x = saturate(LineX(D, U, 0));
            weights.y = saturate(-LineX(D, U, 0));
        }
    }

#if 0
    weights = 0;
    // weights.x = abs(C.x)+abs(C.y)-1;
    weights.y = abs(U.y) == 1;
    // weights.w = di;
    weights *= uLambda;
#endif

    // for(int i = 0; i < 32; i++) {
    //     float2 edge = tex2Dfetch(sEdge, pos + float2(0.0, -i)).xy;
    //     float2 pedge = tex2Dfetch(sEdge, pos + float2(0.0, -i+1)).xy;
    //     if(pedge.x) {
    //         Uw = 1.0;
    //         break;
    //     }
    //     if(!edge.y) break;
    //     U += edge.y;
    // }

    // float D, Dw;
    // for(int i = 0; i < 32; i++) {
    //     float2 edge = tex2Dfetch(sEdge, pos + float2(0, i)).xy;
    //     float2 nedge = tex2Dfetch(sEdge, pos + float2(0, i+1)).xy;
    //     if(nedge.x) {
    //         Dw = 1.0;
    //         break;
    //     }
    //     if(!edge.y) break;
    //     D += edge.y;
    // }

    // if(Dw+Uw > 0 && U + D > 2) {
    //     if(D*Dw > U*Uw) {
    //         weights.x = 2*U/(U+D-1) - 1;
    //     } else {
    //         weights.x = 2*D/(U+D-1) - 1;
    //     }
    // }

    // if(Uw && !Dw && (U > 1 || D > 1) && (U+D-1 > 1)) {
    //     weights.x = D/(U+D-1) - 0.5;
    // }

    return weights;
}

float3 MainPS(in float4 position : SV_Position, in float2 texCoord : TEXCOORD) : SV_Target {
    float2 centerRawEdge = tex2Dfetch(sRawEdge, position.xy).xy;
    float2 centerEdge = tex2Dfetch(sEdge, position.xy).xy;
    float2 eastEdge = tex2Dfetch(sEdge, position.xy + int2(1, 0)).xy;
    float2 southEdge = tex2Dfetch(sEdge, position.xy + int2(0, 1)).xy;

    float4 centerBlendWeights = tex2Dfetch(sBlendWeights, position.xy).rgba;
    float4 eastBlendWeights = tex2Dfetch(sBlendWeights, position.xy + float2(1,0)).rgba;
    float4 southBlendWeights = tex2Dfetch(sBlendWeights, position.xy + float2(0,1)).rgba;

    if(uRenderMode == 1) {
        switch(uTestRender) {
            case 0:
                return float3(centerEdge.xy, 0);
            case 1:
                return float3(centerRawEdge.xy, 0);
            case 2:
                return float3(centerEdge.x, southEdge.x, 0);
            case 3:
                return float3(centerEdge.y, eastEdge.y, 0);
            case 4:
                return centerEdge.x;
            case 5:
                return centerEdge.y;
            case 6:
                return dot(centerEdge, 1) * uLambda;
            default:
                return 0.5;
        }
    } else if(uRenderMode == 2) {
        switch(uTestRender) {
            case 0:
                return float3(centerBlendWeights.xy, 0.0);//*uLambda;
            case 1:
                return float3(centerBlendWeights.zw, 0.0);//*uLambda;
            default:
                return 0.5;
        }
    }

    // return float4(RGB_to_YCoCgR(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0)).rgb), 0.0);

    float3 C = Linear_sRGB_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0,  0)).rgb);
    float3 N = Linear_sRGB_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0, -1)).rgb);
    float3 E = Linear_sRGB_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 1,  0)).rgb);
    float3 S = Linear_sRGB_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2( 0,  1)).rgb);
    float3 W = Linear_sRGB_from_sRGB(tex2Dlod(ReShade::BackBuffer, float4(texCoord, 0.0, 0.0), int2(-1,  0)).rgb);

    // C = lerp(C, W, saturate(centerBlendWeights.x*2.0 - 1.0));
    // C = lerp(C, E, saturate(-eastBlendWeights.x*2.0 + 1.0));

    // if(centerBlendWeights.x > eastBlendWeights.y)
    float Ww = centerBlendWeights.x;
    float Ew = eastBlendWeights.y;
    float Nw = centerBlendWeights.z;
    float Sw = southBlendWeights.w;
    if(Ww + Ew + Nw + Sw > 1e-5) {
        C = lerp(C, (W*Ww + E*Ew + N*Nw + S*Sw)/(Ww + Ew + Nw + Sw), 1 - (1 - Ww) * (1 - Ew) * (1 - Nw) * (1 - Sw));
    }

    // C = lerp(C, W, centerBlendWeights.x);
    // C = lerp(C, E, eastBlendWeights.y);
    // C = lerp(C, N, centerBlendWeights.z);
    // C = lerp(C, S, southBlendWeights.w);

    // // return 2*C - W - E;
    // // return float3(C.yz*0.5 + 0.5, 0.0);

    return sRGB_from_Linear_sRGB(C);
}


technique Dlanis_AA2 <
    ui_label = "Dlanis Anti Aliasing 2";
> {
    pass EdgeDetection {
        VertexShader = PostProcessVS;
        PixelShader = EdgeDetectionPS;
        RenderTarget = tRawEdge;
    }
    pass EdgeFilter {
        VertexShader = PostProcessVS;
        PixelShader = EdgeFilterPS;
        RenderTarget = tEdge;
    }
    pass BlendWeightsCalculation {
        VertexShader = PostProcessVS;
        PixelShader = EdgeWeightsCalculationPS;
        RenderTarget = tBlendWeights;
        ClearRenderTargets = true;
    }
    pass {
        VertexShader = PostProcessVS;
        PixelShader = MainPS;
    }
}

}; // namespace Dlanis_AA2
