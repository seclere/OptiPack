#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

// Camera's RGB vertex shader outputs
struct RGBVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Particle vertex shader outputs and fragment shader inputs
struct ParticleVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
    float3 normal;
};

constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
constant auto yCbCrToRGB = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                    float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                    float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                    float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));
constant float2 viewVertices[] = { float2(-1, 1), float2(-1, -1), float2(1, 1), float2(1, -1) };
constant float2 viewTexCoords[] = { float2(0, 0), float2(0, 1), float2(1, 0), float2(1, 1) };

/// Retrieves the world position of a specified camera point with depth
static simd_float4 worldPoint(simd_float2 cameraPoint, float depth, matrix_float3x3 cameraIntrinsicsInversed, matrix_float4x4 localToWorld) {
    const auto localPoint = cameraIntrinsicsInversed * simd_float3(cameraPoint, 1) * depth;
    const auto worldPoint = localToWorld * simd_float4(localPoint, 1);
    return worldPoint / worldPoint.w;
}

/// Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence
vertex void unprojectVertex(uint vertexID [[vertex_id]],
                            constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                            device ParticleUniforms *particleUniforms [[buffer(kParticleUniforms)]],
                            constant float2 *gridPoints [[buffer(kGridPoints)]],
                            texture2d<float, access::sample> capturedImageTextureY [[texture(kTextureY)]],
                            texture2d<float, access::sample> capturedImageTextureCbCr [[texture(kTextureCbCr)]],
                            texture2d<float, access::sample> depthTexture [[texture(kTextureDepth)]],
                            texture2d<unsigned int, access::sample> confidenceTexture [[texture(kTextureConfidence)]]) {
    
    const auto gridPoint = gridPoints[vertexID];
    const auto currentPointIndex = (uniforms.pointCloudCurrentIndex + vertexID) % uniforms.maxPoints;
    const auto texCoord = clamp(gridPoint / uniforms.cameraResolution, float2(0.0), float2(1.0));

    // Sample depth and confidence
    const float depth = depthTexture.sample(colorSampler, texCoord).r;
    const float confidence = confidenceTexture.sample(colorSampler, texCoord).r;
    float confidenceThresholdFloat = 0.0;

    if (uniforms.confidenceThreshold == 1) {
        confidenceThresholdFloat = 0.5;
    } else if (uniforms.confidenceThreshold == 2) {
        confidenceThresholdFloat = 0.99; // be strict
    }
    if (confidence < float(uniforms.confidenceThreshold) || depth <= 0.001 || !isfinite(depth)) {
        particleUniforms[currentPointIndex].position = float3(0.0);
        particleUniforms[currentPointIndex].color = float3(0.0);
        particleUniforms[currentPointIndex].confidence = 0.0;
        particleUniforms[currentPointIndex].normal = float3(0.0, 0.0, 1.0);
        return;
    }
    // Compute world position
    // First compute the camera-space point:
    const auto cameraPoint = uniforms.cameraIntrinsicsInversed * simd_float3(gridPoint, 1.0) * depth;
    const float4 stabilizedWorld = uniforms.stabilizedCameraTransform * float4(cameraPoint, 1.0);
    // Use original localToWorld only once at write time
    const float3 local = uniforms.cameraIntrinsicsInversed * float3(gridPoint, 1.0) * depth;
    const float4 world = uniforms.localToWorld * float4(local, 1.0);
    particleUniforms[currentPointIndex].position = world.xyz / world.w;



    // Sample color from camera image
    const auto ycbcr = float4(capturedImageTextureY.sample(colorSampler, texCoord).r, capturedImageTextureCbCr.sample(colorSampler, texCoord).rg, 1);
    const auto sampledColor = (yCbCrToRGB * ycbcr).rgb;

    // Compute normals using central difference
    float2 texelSize = 1.0 / uniforms.cameraResolution;
    float2 offsetX = float2(texelSize.x, 0.0);
    float2 offsetY = float2(0.0, texelSize.y);

    float depthLeft = depthTexture.sample(colorSampler, texCoord - offsetX).r;
    float depthRight = depthTexture.sample(colorSampler, texCoord + offsetX).r;
    float depthUp = depthTexture.sample(colorSampler, texCoord - offsetY).r;
    float depthDown = depthTexture.sample(colorSampler, texCoord + offsetY).r;

    float4 posLeft = worldPoint(gridPoint - offsetX * uniforms.cameraResolution, depthLeft, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);
    float4 posRight = worldPoint(gridPoint + offsetX * uniforms.cameraResolution, depthRight, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);
    float4 posUp = worldPoint(gridPoint - offsetY * uniforms.cameraResolution, depthUp, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);
    float4 posDown = worldPoint(gridPoint + offsetY * uniforms.cameraResolution, depthDown, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);

    float3 dx = posRight.xyz - posLeft.xyz;
    float3 dy = posDown.xyz - posUp.xyz;
    float3 normal = normalize(cross(dy, dx));

    // Store output
    particleUniforms[currentPointIndex].position = world.xyz / world.w;
    particleUniforms[currentPointIndex].color = sampledColor;
    particleUniforms[currentPointIndex].confidence = confidence;
    particleUniforms[currentPointIndex].normal = normal;
}

vertex RGBVertexOut rgbVertex(uint vertexID [[vertex_id]],
                              constant RGBUniforms &uniforms [[buffer(0)]]) {
    const float3 texCoord = float3(viewTexCoords[vertexID], 1) * uniforms.viewToCamera;

    RGBVertexOut out;
    out.position = float4(viewVertices[vertexID], 0, 1);
    out.texCoord = texCoord.xy;

    return out;
}

fragment float4 rgbFragment(RGBVertexOut in [[stage_in]],
                            constant RGBUniforms &uniforms [[buffer(0)]],
                            texture2d<float, access::sample> capturedImageTextureY [[texture(kTextureY)]],
                            texture2d<float, access::sample> capturedImageTextureCbCr [[texture(kTextureCbCr)]]) {

    const float2 offset = (in.texCoord - 0.5) * float2(1, 1 / uniforms.viewRatio) * 2;
    const float visibility = saturate(uniforms.radius * uniforms.radius - length_squared(offset));
    const float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord.xy).r, capturedImageTextureCbCr.sample(colorSampler, in.texCoord.xy).rg, 1);

    const float3 sampledColor = (yCbCrToRGB * ycbcr).rgb;
    return float4(sampledColor, 1) * visibility;
}

vertex ParticleVertexOut particleVertex(uint vertexID [[vertex_id]],
                                        constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                                        constant ParticleUniforms *particleUniforms [[buffer(kParticleUniforms)]]) {

    const auto particleData = particleUniforms[vertexID];
    const auto position = particleData.position;
    const auto confidence = particleData.confidence;
    const auto sampledColor = particleData.color;
    const auto visibility = confidence >= uniforms.confidenceThreshold;

    float4 projectedPosition = uniforms.viewProjectionMatrix * float4(position, 1.0);
    const float pointSize = max(uniforms.particleSize / max(1.0, projectedPosition.z), 2.0);
    projectedPosition /= projectedPosition.w;

    ParticleVertexOut out;
    out.position = projectedPosition;
    out.pointSize = pointSize;
    out.color = float4(sampledColor, visibility);
    out.normal = particleData.normal;

    return out;
}

fragment float4 particleFragment(ParticleVertexOut in [[stage_in]],
                                 const float2 coords [[point_coord]]) {

    const float distSquared = length_squared(coords - float2(0.5));
    if (in.color.a == 0 || distSquared > 0.25) {
        discard_fragment();
    }

    // Simple directional lighting
    float3 lightDir = normalize(float3(0.3, 0.3, 1.0));
    float diffuse = max(dot(in.normal, lightDir), 0.0);
    float3 litColor = in.color.rgb * (0.2 + 0.8 * diffuse); // ambient + diffuse

    return float4(litColor, in.color.a);
}
