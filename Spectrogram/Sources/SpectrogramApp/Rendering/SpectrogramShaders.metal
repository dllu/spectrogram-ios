#include <metal_stdlib>
using namespace metal;

struct VertexOutput {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct SpectrogramUniforms {
    uint latestRow;
    uint validRows;
    uint textureHeight;
    uint textureWidth;
    float sampleRate;
    float fftSize;
    float minimumFrequency;
    float maximumFrequency;
};

vertex VertexOutput spectrogramVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };
    constexpr float2 coordinates[] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0),
    };

    VertexOutput output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.textureCoordinate = coordinates[vertexID];
    return output;
}

// Degree-six approximation of matplotlib's perceptually uniform Inferno map.
static float3 inferno(float value) {
    const float3 c0 = float3(0.0002189404, 0.001651005, -0.01948090);
    const float3 c1 = float3(0.1065134, 0.5639564, 3.932712);
    const float3 c2 = float3(11.60249, -3.972854, -15.94239);
    const float3 c3 = float3(-41.70400, 17.43640, 44.35415);
    const float3 c4 = float3(77.16294, -33.40236, -81.80731);
    const float3 c5 = float3(-71.31943, 32.62606, 73.20952);
    const float3 c6 = float3(25.13113, -12.24267, -23.07033);
    return saturate(c0 + value * (c1 + value * (c2 + value * (c3 + value * (
        c4 + value * (c5 + value * c6))))));
}

fragment float4 spectrogramFragment(
    VertexOutput input [[stage_in]],
    texture2d<float> spectrumTexture [[texture(0)]],
    constant SpectrogramUniforms &uniforms [[buffer(0)]]
) {
    if (uniforms.validRows == 0 || uniforms.textureWidth == 0) {
        return float4(0.002, 0.002, 0.004, 1.0);
    }

    const float horizontalPosition = saturate(input.textureCoordinate.x);
    const float frequency = uniforms.minimumFrequency * pow(
        uniforms.maximumFrequency / uniforms.minimumFrequency,
        horizontalPosition
    );
    const float binPosition = frequency * uniforms.fftSize / uniforms.sampleRate;
    const float textureX = (binPosition + 0.5) / float(uniforms.textureWidth);

    const float age = (1.0 - saturate(input.textureCoordinate.y)) * float(uniforms.validRows - 1);
    const uint rowAge = uint(round(age));
    const uint physicalRow = (
        uniforms.latestRow + uniforms.textureHeight - (rowAge % uniforms.textureHeight)
    ) % uniforms.textureHeight;
    const float textureY = (float(physicalRow) + 0.5) / float(uniforms.textureHeight);

    constexpr sampler linearSampler(
        coord::normalized,
        address::clamp_to_edge,
        filter::linear
    );
    const float intensity = spectrumTexture.sample(
        linearSampler,
        float2(textureX, textureY)
    ).r;
    return float4(inferno(intensity), 1.0);
}
