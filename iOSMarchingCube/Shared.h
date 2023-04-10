#pragma once

#include <simd/simd.h>

typedef struct {
    vector_float3 pos;
    vector_float3 normal;
    vector_float4 color;
    float weight;
} TableVertex;

typedef struct {
    float isoValue;
    unsigned int GSPAN;
} MarchingCubeControl;

typedef struct {
    int count;
} Counter;
