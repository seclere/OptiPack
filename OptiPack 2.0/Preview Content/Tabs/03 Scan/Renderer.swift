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
  private let maxPoints = 100_000_00
  // Number of sample points on the grid
  private let numGridPoints = 500
  // Particle's size in pixels
  private let particleSize: Float = 10
  // We only use landscape orientation in this app
  private let orientation = UIInterfaceOrientation.landscapeRight
  // Camera's threshold values for detecting when the camera moves so that we can accumulate the points
  private let cameraRotationThreshold = cos(2 * .degreesToRadian)
  private let cameraTranslationThreshold: Float = pow(0.02, 2)  // (meter-squared)
  // The max number of command buffers in flight
  private let maxInFlightBuffers = 3

  private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
  private let session: ARSession

  // Metal objects and textures
  private let device: MTLDevice
  private let library: MTLLibrary
  private let renderDestination: RenderDestinationProvider
  private let relaxedStencilState: MTLDepthStencilState
  private let depthStencilState: MTLDepthStencilState
  private let commandQueue: MTLCommandQueue
  private lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
  private lazy var rgbPipelineState = makeRGBPipelineState()!
  private lazy var particlePipelineState = makeParticlePipelineState()!
  // texture cache for captured image
  private lazy var textureCache = makeTextureCache()
  private var capturedImageTextureY: CVMetalTexture?
  private var capturedImageTextureCbCr: CVMetalTexture?
  private var depthTexture: CVMetalTexture?
  private var confidenceTexture: CVMetalTexture?

  // Multi-buffer rendering pipeline
  private let inFlightSemaphore: DispatchSemaphore
  private var currentBufferIndex = 0

  // The current viewport size
  private var viewportSize = CGSize()
  // The grid of sample points
  private lazy var gridPointsBuffer = MetalBuffer<Float2>(
    device: device,
    array: makeGridPoints(),
    index: kGridPoints.rawValue, options: [])

  // RGB buffer
  private lazy var rgbUniforms: RGBUniforms = {
    var uniforms = RGBUniforms()
    uniforms.radius = rgbRadius
    uniforms.viewToCamera.copy(from: viewToCamera)
    uniforms.viewRatio = Float(viewportSize.width / viewportSize.height)
    return uniforms
  }()
  private var rgbUniformsBuffers = [MetalBuffer<RGBUniforms>]()
  // Point Cloud buffer
  private lazy var pointCloudUniforms: PointCloudUniforms = {
    var uniforms = PointCloudUniforms()
    uniforms.maxPoints = Int32(maxPoints)
    uniforms.confidenceThreshold = Int32(confidenceThreshold)
    uniforms.particleSize = particleSize
    uniforms.cameraResolution = cameraResolution
    return uniforms
  }()
  private var pointCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]()
  // Particles buffer
  private var particlesBuffer: MetalBuffer<ParticleUniforms>
  private var currentPointIndex = 0
  private var currentPointCount = 0

  // Camera data
  private var sampleFrame: ARFrame { session.currentFrame! }
  private lazy var cameraResolution = Float2(
    Float(sampleFrame.camera.imageResolution.width),
    Float(sampleFrame.camera.imageResolution.height))
  private lazy var viewToCamera = sampleFrame.displayTransform(
    for: orientation, viewportSize: viewportSize
  ).inverted()
  private lazy var lastCameraTransform = sampleFrame.camera.transform

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

  private func updateCapturedImageTextures(frame: ARFrame) {
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

  private func updateDepthTextures(frame: ARFrame) -> Bool {

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

  private func update(frame: ARFrame) {
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

  private func shouldAccumulate(frame: ARFrame) -> Bool {
    let cameraTransform = frame.camera.transform
    return currentPointCount == 0
      || dot(cameraTransform.columns.2, lastCameraTransform.columns.2) <= cameraRotationThreshold
      || distance_squared(cameraTransform.columns.3, lastCameraTransform.columns.3)
        >= cameraTranslationThreshold
  }

  private func accumulatePoints(
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

  func clearOldPointCloudFiles() {
    let fileManager = FileManager.default
    let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

    if let fileURLs = try? fileManager.contentsOfDirectory(
      at: docsURL, includingPropertiesForKeys: nil)
    {
      for fileURL in fileURLs {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "ply" || ext == "zip" {
          do {
            try fileManager.removeItem(at: fileURL)
            print("Deleted old file: \(fileURL.lastPathComponent)")
          } catch {
            print("Failed to delete \(fileURL.lastPathComponent): \(error)")
          }
        }
      }
    }
  }

  func sharePointCloud() {

    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]

    guard
      let fileURLs = try? FileManager.default.contentsOfDirectory(
        at: documentsDirectory, includingPropertiesForKeys: nil),
      let latestFile =
        fileURLs
        .filter({ $0.pathExtension == "ply" })
        .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        .first
    else {
      print("No PLY file found")
      return
    }

    do {
      let zipFileURL = try ZipHelper.zipPLYFile(at: latestFile, in: documentsDirectory)
      print("Zipped file created at: \(zipFileURL.path)")

      let activityViewController = UIActivityViewController(
        activityItems: [zipFileURL], applicationActivities: nil)
      if let rootVC = UIApplication.shared.windows.first?.rootViewController {
        rootVC.present(activityViewController, animated: true)
      }

      ZIPLoader.uploadPointCloud(fileURL: zipFileURL)

      activityViewController.completionWithItemsHandler = { _, completed, _, _ in
        if completed {
          try? FileManager.default.removeItem(at: zipFileURL)
          print("Deleted ZIP file after sharing: \(zipFileURL.lastPathComponent)")
        }
      }

    } catch {
      print("Error while zipping and sharing file: \(error)")
    }
  }

  public func exportMesh() {

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

  public func savePointsToFile() {

    // 1
    var fileToWrite = ""
    let headers = [
      "ply", "format ascii 1.0", "element vertex \(currentPointCount)", "property float x",
      "property float y", "property float z", "property uchar red", "property uchar green",
      "property uchar blue", "property uchar alpha", "element face 0",
      "property list uchar int vertex_indices", "end_header",
    ]
    for header in headers {
      fileToWrite += header
      fileToWrite += "\r\n"
    }

    // 2
    for i in 0..<currentPointCount {

      // 3
      let point = particlesBuffer[i]
      let colors = point.color

      // 4
      let red = Int(colors.x * 255.0).clamped(to: 0...255)
      let green = Int(colors.y * 255.0).clamped(to: 0...255)
      let blue = Int(colors.z * 255.0).clamped(to: 0...255)

      // 5
      let pvValue =
        "\(point.position.x) \(point.position.y) \(point.position.z) \(Int(red)) \(Int(green)) \(Int(blue)) 255"
      fileToWrite += pvValue
      fileToWrite += "\r\n"
    }
    // 6
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    let filename = "ply_\(UUID().uuidString).ply"
    let file = documentsDirectory.appendingPathComponent(filename)
    do {
      // 7
      try fileToWrite.write(to: file, atomically: true, encoding: String.Encoding.ascii)
      sharePointCloud()
      var pendingFiles = UserDefaults.standard.stringArray(forKey: "pendingPLYs") ?? []
      pendingFiles.append(filename)
      UserDefaults.standard.set(pendingFiles, forKey: "pendingPLYs")
      DispatchQueue.global().asyncAfter(deadline: .now() + 30.0) {
        do {
          try FileManager.default.removeItem(at: file)
          print("File deleted after sharing: \(file.path)")
        } catch {
          print("Failed to delete PLY file", error)
        }
      }
    } catch {
      print("Failed to write PLY file", error)
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 120.0) {
      do {
        self.clearOldPointCloudFiles()
      }
    }

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
