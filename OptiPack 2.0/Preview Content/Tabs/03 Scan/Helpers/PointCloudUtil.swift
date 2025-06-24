//
//  MetalSetup.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/24/25.
//

import ARKit
import Metal

extension Renderer {
  func accumulatePoints(
    frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder
  ) {
    pointCloudUniforms.pointCloudCurrentIndex = Int32(currentPointIndex)

    var retainingTextures = [
      capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture,
    ]
    commandBuffer.addCompletedHandler { buffer in
      retainingTextures.removeAll()
    }

    renderEncoder.setDepthStencilState(relaxedStencilState)
    renderEncoder.setRenderPipelineState(unprojectPipelineState)
    renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
    renderEncoder.setVertexBuffer(particlesBuffer)
    renderEncoder.setVertexBuffer(gridPointsBuffer)
    renderEncoder.setVertexTexture(
      CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
    renderEncoder.setVertexTexture(
      CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
    renderEncoder.setVertexTexture(
      CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
    renderEncoder.setVertexTexture(
      CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
    renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridPointsBuffer.count)

    currentPointIndex = (currentPointIndex + gridPointsBuffer.count) % maxPoints
    currentPointCount = min(currentPointCount + gridPointsBuffer.count, maxPoints)
    lastCameraTransform = frame.camera.transform
  }

}
