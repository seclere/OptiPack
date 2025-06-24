//
//  MetalSetup.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/24/25.
//

//
//  PointCloudUtils.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/24/25.
//

import ARKit
import Metal

extension Renderer {

  func makeUnprojectionPipelineState() -> MTLRenderPipelineState? {
    guard let vertexFunction = library.makeFunction(name: "unprojectVertex") else {
      return nil
    }

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.isRasterizationEnabled = false
    descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
    descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat

    return try? device.makeRenderPipelineState(descriptor: descriptor)
  }

  func makeRGBPipelineState() -> MTLRenderPipelineState? {
    guard let vertexFunction = library.makeFunction(name: "rgbVertex"),
      let fragmentFunction = library.makeFunction(name: "rgbFragment")
    else {
      return nil
    }

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
    descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat

    return try? device.makeRenderPipelineState(descriptor: descriptor)
  }

  func makeParticlePipelineState() -> MTLRenderPipelineState? {
    guard let vertexFunction = library.makeFunction(name: "particleVertex"),
      let fragmentFunction = library.makeFunction(name: "particleFragment")
    else {
      return nil
    }

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
    descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    return try? device.makeRenderPipelineState(descriptor: descriptor)
  }

  /// Makes sample points on camera image, also precompute the anchor point for animation
  func makeGridPoints() -> [Float2] {
    let gridArea = cameraResolution.x * cameraResolution.y
    let spacing = sqrt(gridArea / Float(numGridPoints))
    let deltaX = Int(round(cameraResolution.x / spacing))
    let deltaY = Int(round(cameraResolution.y / spacing))

    var points = [Float2]()
    for gridY in 0..<deltaY {
      let alternatingOffsetX = Float(gridY % 2) * spacing / 2
      for gridX in 0..<deltaX {
        let cameraPoint = Float2(
          alternatingOffsetX + (Float(gridX) + 0.5) * spacing, (Float(gridY) + 0.5) * spacing)

        points.append(cameraPoint)
      }
    }

    return points
  }

  func makeTextureCache() -> CVMetalTextureCache {
    // Create captured image texture cache
    var cache: CVMetalTextureCache!
    CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)

    return cache
  }

  func makeTexture(
    fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int
  ) -> CVMetalTexture? {
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

    var texture: CVMetalTexture? = nil
    let status = CVMetalTextureCacheCreateTextureFromImage(
      nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)

    if status != kCVReturnSuccess {
      texture = nil
    }

    return texture
  }
}
