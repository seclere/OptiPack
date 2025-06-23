//
//  PLYFunctions.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/23/25.
//

import Foundation
import QuartzCore
import SceneKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

struct PLYLoaders {
  @EnvironmentObject var authManager: AuthManager

  private var containerWidth = ""
  @State private var containerHeight = ""
  @State private var containerDepth = ""
  @State private var containerMaximumWeight = ""
  @State private var selectedInventoryForExport: Inventory? = nil
  let measurementUnits = ["in", "cm"]
  @State private var isMultiplePLYImporterPresented = false

  @State private var isOpen: Bool = false
  let openPosition: CGFloat = 150
  let closedPosition: CGFloat = 600
  @State private var offsetY: CGFloat = 600

  @State private var selectedInventory: Inventory? = nil

  @State private var scene: SCNScene? = nil
  @StateObject private var keyboardObserver = KeyboardObserver()
  @Environment(\.modelContext) private var context

  @State private var isFileExporterPresented = false
  @State private var selectedPLYURL: URL?

  @State private var searchInput = ""
  @State private var selectedCategory = "All"

  @State private var showUploadPopup = false
  @State private var selectedPLYURLs: [URL] = []
  @State private var isFileImporterPresented = false
  @State private var showDimensionPrompt = false

  @State private var widthInput: String = ""
  @State private var lengthInput: String = ""
  @State private var heightInput: String = ""

  @State var plyMatches: [PLYMatch] = []

  // MARK: PLY Viewer Functions
  func loadSceneFromPLY(at url: URL) {
    guard url.startAccessingSecurityScopedResource() else {
      print("⚠️ Failed to access security-scoped resource.")
      return
    }
    defer { url.stopAccessingSecurityScopedResource() }

    // MARK :: binary identifier
    var isBinaryPLY = false

    do {
      let header = try extractPLYHeader(from: url)
      for line in header.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.starts(with: "format") {
          if trimmed.contains("ascii") {
            isBinaryPLY = false
          } else if trimmed.contains("binary_little_endian")
            || trimmed.contains("binary_big_endian")
          {
            isBinaryPLY = true
          }
          break
        }
      }
    } catch {
      print("Failed to read PLY header: \(error.localizedDescription)")
    }

    // MARK:: resume normal duties
    let fileManager = FileManager.default
    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let safeURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
    print("Original URL: \(url)")
    print("Destination URL: \(safeURL)")
    do {
      if fileManager.fileExists(atPath: safeURL.path) {
        try fileManager.removeItem(at: safeURL)
      }
      try fileManager.copyItem(at: url, to: safeURL)
      do {
        if isBinaryPLY == true {
          do {
            print("i am binary")
            let node = try loadBinaryPLY(from: safeURL)

            // Wrap node with camera and lighting
            let sceneRoot = setupSceneWithCameraAndLighting(rootNode: node)

            let newScene = SCNScene()
            newScene.rootNode.addChildNode(sceneRoot)

            self.scene = newScene

            print("✅ Loaded binary PLY successfully as spheres.")
          } catch {
            print("❌ Error loading PLY: \(error.localizedDescription)")
          }

        } else {
          do {
            let geometry = try loadPLYAsGeometry(from: safeURL)
            let newScene = SCNScene()
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(0, 0, 0)
            newScene.rootNode.addChildNode(node)
            self.scene = newScene
            print("new scene loaded")
          } catch {
            print("Error loading or copying PLY: \(error)")
          }
        }
      } catch {
        print("Failed to determine PLY format: \(error.localizedDescription)")
      }
    } catch { print("file can't be found") }

  }

  func extractPLYHeader(from url: URL) throws -> String {
    let fileHandle = try FileHandle(forReadingFrom: url)
    defer { try? fileHandle.close() }

    var headerData = Data()
    let newline = UInt8(ascii: "\n")

    while true {
      if let byte = try fileHandle.read(upToCount: 1), !byte.isEmpty {
        headerData.append(byte)
        if headerData.count >= 10,  // avoid checking too early
          let headerString = String(data: headerData, encoding: .ascii),
          headerString.contains("end_header")
        {
          break
        }
      } else {
        throw NSError(
          domain: "PLY", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "End of file before end_header"])
      }
    }

    guard let headerText = String(data: headerData, encoding: .ascii) else {
      throw NSError(
        domain: "PLY", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "PLY header is not ASCII-decodable"])
    }

    return headerText
  }

  func readPLYHeader(from file: FileHandle) throws -> (headerText: String, headerSize: Int) {
    var headerData = Data()
    let newlineByte = UInt8(ascii: "\n")

    while true {
      let byte = try file.read(upToCount: 1)
      if let byte = byte, !byte.isEmpty {
        headerData.append(byte)
        if let text = String(data: headerData, encoding: .ascii),
          text.contains("end_header\n") || text.contains("end_header\r\n")
        {
          break
        }
      } else {
        throw NSError(
          domain: "PLY", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "End of file reached before end_header"])
      }
    }

    guard let headerText = String(data: headerData, encoding: .ascii) else {
      throw NSError(
        domain: "PLY", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to decode header as ASCII"])
    }

    return (headerText, headerData.count)
  }

  func isPLYBinary(at url: URL) throws -> Bool {
    guard url.startAccessingSecurityScopedResource() else {
      print("Couldn't access security-scoped resource")
      throw NSError(
        domain: "PLY", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Couldn't access security-scoped resource"])
    }
    defer { url.stopAccessingSecurityScopedResource() }
    // Read just the header chunk (first few KBs)
    let fileHandle = try FileHandle(forReadingFrom: url)
    defer { try? fileHandle.close() }

    let (headerText, headerSize) = try readPLYHeader(from: fileHandle)

    // Look for the "format" line, e.g. "format ascii 1.0" or "format binary_little_endian 1.0"
    for line in headerText.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.starts(with: "format") {
        if trimmed.contains("ascii") {
          return false  // ASCII format
        } else if trimmed.contains("binary_little_endian") || trimmed.contains("binary_big_endian")
        {
          return true  // Binary format
        } else {
          throw NSError(
            domain: "PLY", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown PLY format in header"])
        }
      }
    }

    throw NSError(
      domain: "PLY", code: -1,
      userInfo: [NSLocalizedDescriptionKey: "No format line found in PLY header"])
  }

  func loadPLYAsGeometry(from url: URL) throws -> SCNGeometry {
    print("is the error here")
    let contents = try String(contentsOf: url)
    let lines = contents.components(separatedBy: .newlines).filter {
      !$0.trimmingCharacters(in: .whitespaces).isEmpty
    }
    print("Loaded PLY file with \(lines.count) lines.")

    var vertexCount = 0
    var faceCount = 0
    var headerEnded = false
    var headerLines = 0

    var vertices: [SCNVector3] = []
    var colors: [SCNVector3] = []
    var indices: [Int32] = []

    for (index, line) in lines.enumerated() {
      print("Header Line \(index): \(line)")
      if line.starts(with: "element vertex") {
        vertexCount = Int(line.components(separatedBy: " ").last!) ?? 0
      } else if line.starts(with: "element face") {
        faceCount = Int(line.components(separatedBy: " ").last!) ?? 0
      } else if line == "end_header" {
        headerEnded = true
        headerLines = index + 1
        break
      }
    }
    print("Parsed vertexCount: \(vertexCount), faceCount: \(faceCount)")
    print("Reading vertices from line \(headerLines) to \(headerLines + vertexCount - 1)")
    print(
      "Reading faces from line \(headerLines + vertexCount) to \(headerLines + vertexCount + faceCount - 1)"
    )
    print("First vertex line: \(lines[headerLines])")
    print(
      "Vertices count: \(vertices.count), Indices count: \(indices.count), Colors count: \(colors.count)"
    )

    for (index, line) in lines.enumerated() {
      if line.starts(with: "element vertex") {
        vertexCount = Int(line.components(separatedBy: " ").last!) ?? 0
      } else if line.starts(with: "element face") {
        faceCount = Int(line.components(separatedBy: " ").last!) ?? 0
      } else if line == "end_header" {
        headerEnded = true
        headerLines = index + 1
        break
      }
    }

    guard headerEnded else {
      throw NSError(
        domain: "PLY", code: -1, userInfo: [NSLocalizedDescriptionKey: "Header not found"])
    }

    for i in 0..<vertexCount {
      let comps = lines[headerLines + i].split(separator: " ").map { Float($0) ?? 0 }
      if comps.count >= 6 {
        vertices.append(SCNVector3(comps[0], comps[1], comps[2]))
        colors.append(SCNVector3(comps[3] / 255, comps[4] / 255, comps[5] / 255))
      }
    }

    for i in 0..<faceCount {
      let comps = lines[headerLines + vertexCount + i].split(separator: " ").map { Int32($0) ?? 0 }
      if comps.count >= 4 && comps[0] == 3 {
        indices.append(contentsOf: [comps[1], comps[2], comps[3]])
      }
    }

    let vertexSource = SCNGeometrySource(vertices: vertices)
    let colorData = Data(bytes: colors, count: MemoryLayout<SCNVector3>.stride * colors.count)
    let colorSource = SCNGeometrySource(
      data: colorData,
      semantic: .color,
      vectorCount: colors.count,
      usesFloatComponents: true,
      componentsPerVector: 3,
      bytesPerComponent: MemoryLayout<Float>.stride,
      dataOffset: 0,
      dataStride: MemoryLayout<SCNVector3>.stride)

    let indexData = Data(bytes: indices, count: MemoryLayout<Int32>.stride * indices.count)
    let element = SCNGeometryElement(
      data: indexData,
      primitiveType: .point,  // <-- use .point instead of .triangles
      primitiveCount: vertices.count,
      bytesPerIndex: MemoryLayout<Int32>.stride
    )

    let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
    geometry.firstMaterial?.lightingModel = .blinn
    geometry.firstMaterial?.isDoubleSided = true
    geometry.firstMaterial?.lightingModel = .constant
    geometry.firstMaterial?.readsFromDepthBuffer = false
    geometry.firstMaterial?.isDoubleSided = true
    return geometry

    return SCNGeometry(sources: [vertexSource, colorSource], elements: [element])

  }

  func loadBinaryPLY(from url: URL) throws -> SCNNode {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }

    let (headerText, headerSize) = try readPLYHeader(from: file)
    print("📄 PLY Header Size: \(headerSize) bytes")

    let lines = headerText.components(separatedBy: .newlines)
    guard lines.first == "ply" else {
      throw NSError(
        domain: "PLY", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not a valid PLY file"])
    }

    guard lines.contains(where: { $0.contains("format binary_little_endian") }) else {
      throw NSError(
        domain: "PLY", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Only binary_little_endian PLY files supported"])
    }

    var vertexCount = 0
    var faceCount = 0

    for line in lines {
      if line.starts(with: "element vertex") {
        vertexCount = Int(line.split(separator: " ").last!) ?? 0
      } else if line.starts(with: "element face") {
        faceCount = Int(line.split(separator: " ").last!) ?? 0
      }
    }

    print("🔢 Vertex Count: \(vertexCount)")
    print("🔢 Face Count: \(faceCount)")

    var vertices = [SCNVector3]()
    var colors = [SCNVector3]()

    try file.seek(toOffset: UInt64(headerSize))
    let vertexSize = 51

    for i in 0..<vertexCount {
      let data = try file.read(upToCount: vertexSize) ?? Data()
      guard data.count == vertexSize else {
        print("❌ Vertex \(i): Incomplete data (\(data.count) bytes)")
        continue
      }

      var x: Double = 0
      var y: Double = 0
      var z: Double = 0
      let r = data[48]
      let g = data[49]
      let b = data[50]

      // Read double precision position
      _ = withUnsafeMutableBytes(of: &x) { data.copyBytes(to: $0, from: 0..<8) }
      _ = withUnsafeMutableBytes(of: &y) { data.copyBytes(to: $0, from: 8..<16) }
      _ = withUnsafeMutableBytes(of: &z) { data.copyBytes(to: $0, from: 16..<24) }

      let vertex = SCNVector3(Float(x), Float(y), Float(z))
      let color = SCNVector3(Float(r) / 255, Float(g) / 255, Float(b) / 255)

      if !vertex.x.isFinite || !vertex.y.isFinite || !vertex.z.isFinite {
        print("❌ Invalid vertex at index \(i): \(vertex)")
        continue
      }

      vertices.append(vertex)
      colors.append(color)
    }

    print("✅ Loaded \(vertices.count) valid vertices")

    guard !vertices.isEmpty else {
      print("🚫 No vertices loaded. Check file format or data offsets.")
      return SCNNode()  // Return empty node
    }

    // Create point cloud geometry from vertices and colors
    let geometryNode = SCNNode(
      geometry: createPointCloudGeometry(vertices: vertices, colors: colors))

    print("🎯 Created point cloud geometry node with \(vertices.count) points")
    return geometryNode
  }

  func createPointCloudGeometry(vertices: [SCNVector3], colors: [SCNVector3]) -> SCNGeometry {
    // Create vertex source
    let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
    let vertexSource = SCNGeometrySource(
      data: vertexData,
      semantic: .vertex,
      vectorCount: vertices.count,
      usesFloatComponents: true,
      componentsPerVector: 3,
      bytesPerComponent: MemoryLayout<Float>.size,
      dataOffset: 0,
      dataStride: MemoryLayout<SCNVector3>.size)

    // Create color source
    let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.size)
    let colorSource = SCNGeometrySource(
      data: colorData,
      semantic: .color,
      vectorCount: colors.count,
      usesFloatComponents: true,
      componentsPerVector: 3,
      bytesPerComponent: MemoryLayout<Float>.size,
      dataOffset: 0,
      dataStride: MemoryLayout<SCNVector3>.size)

    // Create geometry element with point primitive type
    var indices = [Int32]()
    for i in 0..<vertices.count {
      indices.append(Int32(i))
    }
    let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
    let geometryElement = SCNGeometryElement(
      data: indexData,
      primitiveType: .point,
      primitiveCount: vertices.count,
      bytesPerIndex: MemoryLayout<Int32>.size)

    let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [geometryElement])
    geometry.firstMaterial?.lightingModel = .constant  // no lighting, color only
    geometry.firstMaterial?.readsFromDepthBuffer = false
    geometry.firstMaterial?.writesToDepthBuffer = false
    geometry.firstMaterial?.shaderModifiers = [
      .geometry: """
      uniform float pointSize;
      void geometry() {
          gl_PointSize = pointSize;
      }
      """
    ]
    geometry.firstMaterial?.setValue(5.0, forKey: "pointSize")

    geometry.firstMaterial?.isDoubleSided = true

    return geometry
  }

  /// Wrap the root node in a container scene node with camera and ambient lighting
  func setupSceneWithCameraAndLighting(rootNode: SCNNode) -> SCNNode {
    let containerNode = SCNNode()
    containerNode.addChildNode(rootNode)

    // Calculate bounding box of the point cloud
    let (min, max) = rootNode.boundingBox
    let center = SCNVector3(
      (min.x + max.x) / 2,
      (min.y + max.y) / 2,
      (min.z + max.z) / 2
    )
    let size = SCNVector3(
      max.x - min.x,
      max.y - min.y,
      max.z - min.z
    )

    // Setup camera node
    let cameraNode = SCNNode()
    let camera = SCNCamera()
    camera.usesOrthographicProjection = false
    camera.zNear = 0.001
    camera.zFar = 1000
    cameraNode.camera = camera

    // Position camera so it looks at the center from front with some distance
    let (minVec, maxVec) = rootNode.boundingBox
    let distance = Swift.max(size.x, size.y, size.z) * 2.0

    cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
    cameraNode.look(at: center)
    containerNode.addChildNode(cameraNode)

    // Ambient light
    let ambientLight = SCNLight()
    ambientLight.type = .ambient
    ambientLight.color = UIColor(white: 1.0, alpha: 1.0)
    let ambientLightNode = SCNNode()
    ambientLightNode.light = ambientLight
    containerNode.addChildNode(ambientLightNode)

    return containerNode
  }

  // MARK: PLY Matching Functions

}

class PLYStateModels: ObservableObject {

  @State var plyMatches: [PLYMatch] = []
  let PLYLoader = PLYLoaders()

  func buildPLYMatchesFromDownloads() {
    print("🚀 buildPLYMatchesFromDownloads was called")
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let unzippedFolderURL = documentsURL.appendingPathComponent("UnzippedPLY")

    var matches: [PLYMatch] = []

    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: unzippedFolderURL, includingPropertiesForKeys: nil)
      let plyFiles = fileURLs.filter { $0.pathExtension.lowercased() == "ply" }

      for url in plyFiles {
        print("🔍 Scanning file: \(url.lastPathComponent)")

        do {
          let node = try PLYLoader.loadBinaryPLY(from: url)  // or loadSceneFromPLY
          matches.append(PLYMatch(plyURL: url, matchedJSON: nil, previewNode: node))
          print("✅ Loaded preview for: \(url.lastPathComponent)")
        } catch {
          print(
            "❌ Failed to load preview for \(url.lastPathComponent): \(error.localizedDescription)")
        }

      }

      self.plyMatches = matches

    } catch {
      print("❌ Failed to read UnzippedPLY folder: \(error.localizedDescription)")
    }
  }

}
