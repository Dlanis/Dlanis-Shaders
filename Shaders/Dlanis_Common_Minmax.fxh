// SPDX-FileCopyrightText: © 2025 Danil Bagautdinov
// SPDX-License-Identifier: MPL-2.0

#pragma once

#define FUNC9(N, F, T) \
    T N(T a, T b) { return F(a, b); } \
    T N(T a, T b, T c) { return N(N(a, b), c); } \
    T N(T a, T b, T c, T d) { return N(N(a, b, c), d); } \
    T N(T a, T b, T c, T d, T e) { return N(N(a, b, c, d), e); } \
    T N(T a, T b, T c, T d, T e, T f) { return N(N(a, b, c, d, e), f); } \
    T N(T a, T b, T c, T d, T e, T f, T g) { return N(N(a, b, c, d, e, f), g); } \
    T N(T a, T b, T c, T d, T e, T f, T g, T h) { return N(N(a, b, c, d, e, f, g), h); } \
    T N(T a, T b, T c, T d, T e, T f, T g, T h, T i) { return N(N(a, b, c, d, e, f, g, h), i); }

FUNC9(Min, min, float)
FUNC9(Min2, min, float2)
FUNC9(Min3, min, float3)
FUNC9(Min4, min, float4)
FUNC9(Min, min, int)
FUNC9(Min2, min, int2)
FUNC9(Min3, min, int3)
FUNC9(Min4, min, int4)
FUNC9(Min, min, uint)
FUNC9(Min2, min, uint2)
FUNC9(Min3, min, uint3)
FUNC9(Min4, min, uint4)

FUNC9(Max, max, float)
FUNC9(Max2, max, float2)
FUNC9(Max3, max, float3)
FUNC9(Max4, max, float4)
FUNC9(Max, max, int)
FUNC9(Max2, max, int2)
FUNC9(Max3, max, int3)
FUNC9(Max4, max, int4)
FUNC9(Max, max, uint)
FUNC9(Max2, max, uint2)
FUNC9(Max3, max, uint3)
FUNC9(Max4, max, uint4)

#undef FUNC9

float MinC(float2 v) { return Min(v.x, v.y); }
float MinC(float3 v) { return Min(v.x, v.y, v.z); }
float MinC(float4 v) { return Min(v.x, v.y, v.z, v.w); }

int MinC(int2 v) { return Min(v.x, v.y); }
int MinC(int3 v) { return Min(v.x, v.y, v.z); }
int MinC(int4 v) { return Min(v.x, v.y, v.z, v.w); }

uint MinC(uint2 v) { return Min(v.x, v.y); }
uint MinC(uint3 v) { return Min(v.x, v.y, v.z); }
uint MinC(uint4 v) { return Min(v.x, v.y, v.z, v.w); }

float MaxC(float2 v) { return Max(v.x, v.y); }
float MaxC(float3 v) { return Max(v.x, v.y, v.z); }
float MaxC(float4 v) { return Max(v.x, v.y, v.z, v.w); }

int MaxC(int2 v) { return Max(v.x, v.y); }
int MaxC(int3 v) { return Max(v.x, v.y, v.z); }
int MaxC(int4 v) { return Max(v.x, v.y, v.z, v.w); }

uint MaxC(uint2 v) { return Max(v.x, v.y); }
uint MaxC(uint3 v) { return Max(v.x, v.y, v.z); }
uint MaxC(uint4 v) { return Max(v.x, v.y, v.z, v.w); }
