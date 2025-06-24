//
//  Renderer.swift
//  OptiPack UI
//
//  Created by Ysrael Salces on 2/17/25.
//

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The host app renderer.
*/

import ARKit
import Compression
import CoreImage
import Foundation
import MachO  // Add if needed
import Metal
import MetalKit
import UIKit
import ZIPFoundation
import os

final class Renderer {
  // Maximum number of points we store in the point cloud
  let maxPoints = 100_000_00
  // Number of sample points on the grid
  let numGridPoints = 500
  // Particle's size in pixels
  let particleSize: Float = 10
  // We only use landscape orientation in this app
  let orientation = UIInterfaceOrientation.landscapeRight
  // Camera's threshold values for detecting when the camera moves so that we can accumulate the points
  let cameraRotationThreshold = cos(2 * .degreesToRadian)
  let cameraTranslationThreshold: Float = pow(0.02, 2)  // (meter-squared)
  // The max number of command buffers in flight
  let maxInFlightBuffers = 3

  lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
  let session: ARSession

  // Metal objects and textures
  let device: MTLDevice
  let library: MTLLibrary
  let renderDestination: RenderDestinationProvider
  let relaxedStencilState: MTLDepthStencilState
  let depthStencilState: MTLDepthStencilState
  let commandQueue: MTLCommandQueue
  lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
  lazy var rgbPipelineState = makeRGBPipelineState()!
  lazy var particlePipelineState = makeParticlePipelineState()!
  // texture cache for captured image
  lazy var textureCache = makeTextureCache()
  var capturedImageTextureY: CVMetalTexture?
  var capturedImageTextureCbCr: CVMetalTexture?
  var depthTexture: CVMetalTexture?
  var confidenceTexture: CVMetalTexture?

  // Multi-buffer rendering pipeline
  let inFlightSemaphore: DispatchSemaphore
  var currentBufferIndex = 0

  // The current viewport size
  var viewportSize = CGSize()
  // The grid of sample points
  lazy var gridPointsBuffer = MetalBuffer<Float2>(
    device: device,
    array: makeGridPoints(),
    index: kGridPoints.rawValue, options: [])

  // RGB buffer
  lazy var rgbUniforms: RGBUniforms = {
    var uniforms = RGBUniforms()
    uniforms.radius = rgbRadius
    uniforms.viewToCamera.copy(from: viewToCamera)
    uniforms.viewRatio = Float(viewportSize.width / viewportSize.height)
    return uniforms
  }()
  var rgbUniformsBuffers = [MetalBuffer<RGBUniforms>]()
  // Point Cloud buffer
  lazy var pointCloudUniforms: PointCloudUniforms = {
    var uniforms = PointCloudUniforms()
    uniforms.maxPoints = Int32(maxPoints)
    uniforms.confidenceThreshold = Int32(confidenceThreshold)
    uniforms.particleSize = particleSize
    uniforms.cameraResolution = cameraResolution
    return uniforms
  }()
  var pointCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]()
  // Particles buffer
  var particlesBuffer: MetalBuffer<ParticleUniforms>
  var currentPointIndex = 0
  var currentPointCount = 0

  // Camera data
  var sampleFrame: ARFrame { session.currentFrame! }
  lazy var cameraResolution = Float2(
    Float(sampleFrame.camera.imageResolution.width),
    Float(sampleFrame.camera.imageResolution.height))
  lazy var viewToCamera = sampleFrame.displayTransform(
    for: orientation, viewportSize: viewportSize
  ).inverted()
  lazy var lastCameraTransform = sampleFrame.camera.transform

  var isScanning: Bool = false
  var showCameraFeed = true

  // interfaces
  var confidenceThreshold = 1 {
    didSet {
      // apply the change for the shader
      pointCloudUniforms.confidenceThreshold = Int32(confidenceThreshold)
    }
  }

  var rgbRadius: Float = 0 {
    didSet {
      // apply the change for the shader
      rgbUniforms.radius = rgbRadius
    }
  }

  let ZIPLoader = ZIPLoaders()

  init(
    session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider
  ) {
    self.session = session
    self.device = device
    self.renderDestination = renderDestination

    library = device.makeDefaultLibrary()!
    commandQueue = device.makeCommandQueue()!

    // initialize our buffers
    for _ in 0..<maxInFlightBuffers {
      rgbUniformsBuffers.append(.init(device: device, count: 1, index: 0))
      pointCloudUniformsBuffers.append(
        .init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
    }
    particlesBuffer = .init(device: device, count: maxPoints, index: kParticleUniforms.rawValue)

    // rbg does not need to read/write depth
    let relaxedStateDescriptor = MTLDepthStencilDescriptor()
    relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!

    // setup depth test for point cloud
    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = .lessEqual
    depthStateDescriptor.isDepthWriteEnabled = true
    depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!

    inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
  }

  func drawRectResized(size: CGSize) {
    viewportSize = size
  }

  func updateCapturedImageTextures(frame: ARFrame) {
    // Create two textures (Y and CbCr) from the provided frame's captured image
    let pixelBuffer = frame.capturedImage
    guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
      return
    }

    capturedImageTextureY = makeTexture(
      fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
    capturedImageTextureCbCr = makeTexture(
      fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
  }

  func updateDepthTextures(frame: ARFrame) -> Bool {

    guard isScanning else { return false }

    guard let depthMap = frame.sceneDepth?.depthMap,
      let confidenceMap = frame.sceneDepth?.confidenceMap
    else {
      return false
    }

    depthTexture = makeTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0)
    confidenceTexture = makeTexture(
      fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0)

    return true
  }

  func update(frame: ARFrame) {
    // frame dependent info
    let camera = frame.camera
    let cameraIntrinsicsInversed = camera.intrinsics.inverse
    let viewMatrix = camera.viewMatrix(for: orientation)
    let viewMatrixInversed = viewMatrix.inverse
    let projectionMatrix = camera.projectionMatrix(
      for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
    pointCloudUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
    pointCloudUniforms.localToWorld = viewMatrixInversed * rotateToARCamera
    pointCloudUniforms.cameraIntrinsicsInversed = cameraIntrinsicsInversed
  }

  func draw() {
    guard let currentFrame = session.currentFrame,
      let renderDescriptor = renderDestination.currentRenderPassDescriptor,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)
    else {
      return
    }

    //        commandBuffer.addCompletedHandler { [self] _ in
    //            print(particlesBuffer[9].position) // Prints the 10th particles position
    //        }

    _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
    commandBuffer.addCompletedHandler { [weak self] commandBuffer in
      if let self = self {
        self.inFlightSemaphore.signal()
      }
    }

    // update frame data
    update(frame: currentFrame)
    updateCapturedImageTextures(frame: currentFrame)

    // handle buffer rotating
    currentBufferIndex = (currentBufferIndex + 1) % maxInFlightBuffers
    pointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms

    if shouldAccumulate(frame: currentFrame), updateDepthTextures(frame: currentFrame) {
      accumulatePoints(
        frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
    }

    // check and render rgb camera image
    if rgbUniforms.radius > 0 {
      var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr]
      commandBuffer.addCompletedHandler { buffer in
        retainingTextures.removeAll()
      }
      rgbUniformsBuffers[currentBufferIndex][0] = rgbUniforms

      renderEncoder.setDepthStencilState(relaxedStencilState)
      renderEncoder.setRenderPipelineState(rgbPipelineState)
      renderEncoder.setVertexBuffer(rgbUniformsBuffers[currentBufferIndex])
      renderEncoder.setFragmentBuffer(rgbUniformsBuffers[currentBufferIndex])
      renderEncoder.setFragmentTexture(
        CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
      renderEncoder.setFragmentTexture(
        CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
      renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    // render particles
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setRenderPipelineState(particlePipelineState)
    renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
    renderEncoder.setVertexBuffer(particlesBuffer)
    renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: currentPointCount)
    renderEncoder.endEncoding()

    commandBuffer.present(renderDestination.currentDrawable!)
    commandBuffer.commit()
  }

  func shouldAccumulate(frame: ARFrame) -> Bool {
    let cameraTransform = frame.camera.transform
    return currentPointCount == 0
      || dot(cameraTransform.columns.2, lastCameraTransform.columns.2) <= cameraRotationThreshold
      || distance_squared(cameraTransform.columns.3, lastCameraTransform.columns.3)
        >= cameraTranslationThreshold
  }

  func resetScanning() {
    // Reset indices and counts
    currentPointIndex = 0
    currentPointCount = 0

    // Clear GPU particles buffer up to maxPoints (avoid out-of-bounds)
    for i in 0..<maxPoints {
      particlesBuffer[i].position = SIMD3<Float>(0, 0, 0)
      particlesBuffer[i].color = SIMD3<Float>(0, 0, 0)
      particlesBuffer[i].confidence = 0
      particlesBuffer[i].normal = SIMD3<Float>(0, 0, 1)
    }

    // Reset last camera transform to current frame camera transform
    if let frame = session.currentFrame {
      lastCameraTransform = frame.camera.transform
    }

    // Clear CPU-side points array if used
    points.removeAll()

    print("Scanning reset")
  }
}

// MARK: - Scanning Control
var isScanning = false
private(set) var points = [SIMD3<Float>]()

func startScanning() {
  isScanning = true
  print("Started scanning.")
}

func stopScanning() {
  isScanning = false
  print("Stopped scanning.")
}

func clearPoints() {
  points.removeAll()
  print("Cleared all points.")
}

// MARK: - Metal Helpers

extension Renderer {

  static func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
    switch orientation {
    case .landscapeLeft:
      return 180
    case .portrait:
      return 90
    case .portraitUpsideDown:
      return -90
    default:
      return 0
    }
  }

  static func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
    // flip to ARKit Camera's coordinate
    let flipYZ = matrix_float4x4(
      [1, 0, 0, 0],
      [0, -1, 0, 0],
      [0, 0, -1, 0],
      [0, 0, 0, 1])

    let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
    return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
  }

  func currentCameraImage() -> UIImage? {
    guard let frame = session.currentFrame else { return nil }

    let pixelBuffer = frame.capturedImage
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()

    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    return min(max(self, limits.lowerBound), limits.upperBound)
  }
}
