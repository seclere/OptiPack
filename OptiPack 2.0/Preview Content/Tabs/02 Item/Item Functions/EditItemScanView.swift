import SceneKit
import SwiftData
import SwiftUI

struct EditItemScanView: View {
  @Bindable var scan: ItemDetails
  // Existing states
  @State private var plyNode: SCNNode? = nil
  @State private var plyLoadingError: String? = nil

  // Add a path/url for your PLY file (update with your actual source)
  // Store only the filename:
  /*
  private var plyFileURL: URL? {
      Bundle.main.url(forResource: "THE-FOX", withExtension: "ply")
  }
  @State private var plyFileName: String? = "THE-FOX.ply"
  */
  @State private var plyFileName: String? = nil
  private var plyFileURL: URL? {
    guard let plyFileName = plyFileName else { return nil }
    return Bundle.main.url(
      forResource: plyFileName.replacingOccurrences(of: ".ply", with: ""), withExtension: "ply")
  }

  @State private var showConfirmationAlert = false
  @State private var isEditing = false
  @Environment(\.modelContext) private var modelContext

  @EnvironmentObject var authManager: AuthManager

  @Query private var allInventories: [Inventory]

  private var inventories: [Inventory] {
    guard let cluster = authManager.currentUser?.inventoryCluster else { return [] }
    return allInventories.filter { cluster.inventories.contains($0) }
  }

  @State private var showInventoryPicker = false
  @State private var selectedInventoryIndex: Int? = nil
  @State private var showPLYViewer = false

  var body: some View {
    NavigationStack {
      ZStack {
        /*VStack {
            if let node = plyNode {
                MiniPLYViewer(node: node)
                    .frame(height: 180)
                    .padding()
            } else if let error = plyLoadingError {
                Text("Failed to load PLY: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ProgressView("Loading 3D preview...")
                    .padding()
            }*/
        Form {
          Section {
            HStack {
              Spacer()

              Button {
                if let fileName = scan.item?.plyFileName {
                  selectPLYFile(named: "THE-FOX.ply")
                  showPLYViewer = true
                } else {
                  print("No file name found for item")
                }
              } label: {
                Image(systemName: "cube.box.fill")
                Text("View item")
                Spacer()
              }

              Spacer()
            }.padding(.top, 20)
              .padding()
          }

          Section(
            header: Text("Item Details")
              .font(.system(size: 15))
          ) {

            VStack(alignment: .leading, spacing: 4) {
              Text("Item Name")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", text: $scan.itemName)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Category")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              Picker("", selection: $scan.itemCategory) {
                ForEach(fixedCategory.allCases, id: \.self) { category in
                  Text(category.rawValue).tag(category)
                }
              }
              .pickerStyle(.segmented)
              .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Width (cm)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.width, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Depth (cm)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.depth, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Height (cm)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.height, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Weight (kg)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.weight, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            Toggle("Stackable", isOn: $scan.stackable)
              .disabled(!isEditing)
              .tint(.teal)
            Toggle("Fragile", isOn: $scan.fragile)
              .disabled(!isEditing)
              .tint(.teal)

            if !isEditing {
              HStack {
                Button(action: {
                  showInventoryPicker = true
                }) {
                  HStack {
                    Image(systemName: "plus")
                    Text("Add to Inventory")
                      .font(.system(size: 17))
                  }
                }

                if showInventoryPicker {
                  Picker("", selection: $selectedInventoryIndex) {
                    ForEach(inventories.indices, id: \.self) { index in
                      Text(inventories[index].inventoryName)
                        .tag(index as Int?)
                    }
                  }
                  .pickerStyle(.menu)
                  .padding()
                  .onChange(of: selectedInventoryIndex) { newIndex in
                    if let index = newIndex, index < inventories.count {
                      //moveItemToInventory(to: inventories[index])
                      if let item = scan.item {
                        let selectedInventoryName = inventories[index].inventoryName
                        moveItemToInventory(
                          named: selectedInventoryName,
                          item: item,
                          context: modelContext,
                          allInventories: inventories
                        )

                      }
                      selectedInventoryIndex = nil
                      showInventoryPicker = false
                    }
                  }
                }
              }
            }

            if isEditing {
              HStack {
                Button(action: {
                  showConfirmationAlert = true
                }) {
                  HStack {
                    Image(systemName: "trash.fill")
                      .foregroundColor(.red)
                    Text("Delete Item")
                      .foregroundColor(.red)
                  }
                }
                .alert(isPresented: $showConfirmationAlert) {
                  Alert(
                    title: Text("Are you sure?"),
                    message: Text(
                      "Do you really want to delete this item? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                      deleteItem()
                    },
                    secondaryButton: .cancel()
                  )
                }

                Spacer()
              }
            }
          }
        }
        .foregroundColor(isEditing ? .primary : .teal)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              withAnimation(.easeInOut(duration: 0.2)) {
                isEditing.toggle()
              }
              print("Edit mode: \(isEditing)")
            } label: {
              Image(systemName: isEditing ? "" : "pencil")
                .foregroundColor(isEditing ? .teal : .secondary)

              Text(isEditing ? "Done" : "Edit")
                .foregroundColor(isEditing ? .teal : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .font(.system(size: 17))
          }
        }

        .sheet(isPresented: $showPLYViewer) {
          if let node = plyNode {
            Button {
              showPLYViewer = false
            } label: {
              HStack {
                Spacer()
                Text("Close Preview").padding()
              }
            }
            SCNViewWrapper(node: node)
          } else if let error = plyLoadingError {
            Text("Failed to load PLY: \(error)")
              .foregroundColor(.red)
              .padding()
          } else {
            ProgressView("Loading PLY preview...")
              .padding()
              .onAppear {
                if let url = plyFileURL {
                  loadSceneFromPLY(at: url)
                } else {
                  plyLoadingError = "PLY file URL not found"
                }
              }

          }
        }
      }
    }
    .onAppear {
      print("eh, it's loading?")
    }
    .onDisappear {
      plyNode = nil
      plyLoadingError = nil
    }

  }

  private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  func selectPLYFile(named fileName: String) {
    plyFileName = fileName
  }

  private func getPLYFileURL(from fileName: String) -> URL {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsURL.appendingPathComponent(fileName)
  }

  func savePLYData(_ data: Data, withFileName fileName: String) throws {
    let url = getPLYFileURL(from: fileName)
    try data.write(to: url)
    plyFileName = fileName  // store just the filename
  }

  // MARK: - Load PLY Scene
  func loadSceneFromPLY(at url: URL) {
    let isBundledFile = url.path.contains(Bundle.main.bundlePath)
    if !isBundledFile {
      guard url.startAccessingSecurityScopedResource() else {
        print("⚠️ Failed to access security-scoped resource.")
        return
      }
      defer { url.stopAccessingSecurityScopedResource() }
    } else {
      print("🟢 Accessing bundled file: \(url.lastPathComponent)")
    }

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
            let newScene = SCNScene()
            newScene.rootNode.addChildNode(node)
            DispatchQueue.main.async {
              self.plyNode = node  // <-- This triggers the UI update!
            }
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
            DispatchQueue.main.async {
              self.plyNode = node  // <-- This triggers the UI update!
            }
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

  // MARK: header
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

  // MARK: loaders
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

    try file.seek(toOffset: UInt64(headerSize))
    let vertexSize = MemoryLayout<Double>.stride * 3 + MemoryLayout<UInt8>.stride * 3  // 8*3 + 1*3 = 27 bytes

    var vertices: [SCNVector3] = []
    var colors: [SCNVector3] = []

    for _ in 0..<vertexCount {
      let data = try file.read(upToCount: vertexSize) ?? Data()
      guard data.count == vertexSize else { continue }

      var x: Double = 0
      var y: Double = 0
      var z: Double = 0
      var r: UInt8 = 0
      var g: UInt8 = 0
      var b: UInt8 = 0

      _ = withUnsafeMutableBytes(of: &x) { data.copyBytes(to: $0, from: 0..<8) }
      _ = withUnsafeMutableBytes(of: &y) { data.copyBytes(to: $0, from: 8..<16) }
      _ = withUnsafeMutableBytes(of: &z) { data.copyBytes(to: $0, from: 16..<24) }

      r = data[24]
      g = data[25]
      b = data[26]

      // Convert Double to Float for SCNVector3:
      vertices.append(SCNVector3(Float(x), Float(y), Float(z)))
      colors.append(SCNVector3(Float(r) / 255, Float(g) / 255, Float(b) / 255))
    }

    // Optional: parse faces if needed (here we skip it for point cloud)

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

    // Create a dummy index buffer to draw as points
    var indices = Array(0..<Int32(vertices.count))
    let indexData = Data(bytes: &indices, count: MemoryLayout<Int32>.stride * indices.count)
    let element = SCNGeometryElement(
      data: indexData,
      primitiveType: .point,
      primitiveCount: indices.count,
      bytesPerIndex: MemoryLayout<Int32>.stride)

    let rootNode = SCNNode()

    for (i, vertex) in vertices.enumerated() {
      let sphere = SCNSphere(radius: 0.002)  // Adjust radius for desired size
      sphere.firstMaterial?.diffuse.contents = UIColor(
        red: CGFloat(colors[i].x),
        green: CGFloat(colors[i].y),
        blue: CGFloat(colors[i].z),
        alpha: 1.0
      )
      let sphereNode = SCNNode(geometry: sphere)
      sphereNode.position = vertex
      rootNode.addChildNode(sphereNode)
    }

    return rootNode
  }

  private func deleteItem() {
    if let item = scan.item {
      for inventory in item.inventories {
        if let idx = inventory.items.firstIndex(where: { $0 === item }) {
          inventory.items.remove(at: idx)
        }
      }

      modelContext.delete(item)
      try? modelContext.save()
    }
  }

  func moveItemToInventory(
    named inventoryName: String, item: Item, context: ModelContext, allInventories: [Inventory]
  ) {
    // Find the destination inventory by name
    guard
      let destinationInventory = allInventories.first(where: { $0.inventoryName == inventoryName })
    else {
      print("Inventory not found")
      return
    }

    // Check if it's already in that inventory
    if destinationInventory.items.contains(where: { $0.id == item.id }) {
      print("Item already exists in that inventory")
      return
    }

    // Add the item to the new inventory
    destinationInventory.items.append(item)

    do {
      try context.save()
      print("Item added to inventory \(inventoryName)")
    } catch {
      print("Failed to add item: \(error)")
    }
  }
}

struct SimplePLYViewer: View {
  @State private var plyNode: SCNNode?
  @State private var plyLoadingError: String?

  private var plyFileURL: URL? {
    Bundle.main.url(forResource: "THE-FOX", withExtension: "ply")
  }
  @State private var plyFileName: String? = "THE-FOX.ply"

  var body: some View {
    VStack {
      if let node = plyNode {
        SCNViewWrapper(node: node)
          .frame(height: 300)
      } else if let error = plyLoadingError {
        Text("Failed to load PLY: \(error)")
          .foregroundColor(.red)
          .padding()
      } else {
        ProgressView("Loading 3D preview...")
          .padding()
      }
    }
    .onAppear(perform: loadPLYPreview)
    .navigationTitle("PLY Viewer")
  }

  private func loadPLYPreview() {
    guard let fileName = plyFileName else {
      plyLoadingError = "No PLY file name found"
      return
    }

    guard let url = plyFileURL else {
      plyLoadingError = "No PLY file URL found"
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let node = try loadBinaryPLY(from: url)
        print("PLY loaded successfully, vertices count: \(node.childNodes.count)")
        DispatchQueue.main.async {
          plyNode = node
        }
      } catch {
        DispatchQueue.main.async {
          plyLoadingError = error.localizedDescription
          print("PLY loading failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func readPLYHeader(from file: FileHandle) throws -> (headerText: String, headerSize: Int)
  {
    var headerData = Data()
    let newlineByte = UInt8(ascii: "\n")
    print("the header exists?")
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

  private func loadBinaryPLY(from url: URL) throws -> SCNNode {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }

    let (headerText, headerSize) = try readPLYHeader(from: file)

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

    print("eh, the file exists?")

    var vertexCount = 0
    var faceCount = 0

    for line in lines {
      if line.starts(with: "element vertex") {
        vertexCount = Int(line.split(separator: " ").last!) ?? 0
      } else if line.starts(with: "element face") {
        faceCount = Int(line.split(separator: " ").last!) ?? 0
      }
    }

    try file.seek(toOffset: UInt64(headerSize))
    let vertexSize = MemoryLayout<Double>.stride * 3 + MemoryLayout<UInt8>.stride * 3  // 8*3 + 1*3 = 27 bytes

    var vertices: [SCNVector3] = []
    var colors: [SCNVector3] = []

    let centroid = SCNVector3(
      vertices.map { $0.x }.reduce(0, +) / Float(vertices.count),
      vertices.map { $0.y }.reduce(0, +) / Float(vertices.count),
      vertices.map { $0.z }.reduce(0, +) / Float(vertices.count)
    )
    let centeredVertices = vertices.map { vertex in
      SCNVector3(
        vertex.x - centroid.x,
        vertex.y - centroid.y,
        vertex.z - centroid.z)
    }
    let invCount = 1.0 / Float(vertices.count)
    let center = SCNVector3(centroid.x * invCount, centroid.y * invCount, centroid.z * invCount)

    for _ in 0..<vertexCount {
      let data = try file.read(upToCount: vertexSize) ?? Data()
      guard data.count == vertexSize else { continue }

      var x: Double = 0
      var y: Double = 0
      var z: Double = 0
      var r: UInt8 = 0
      var g: UInt8 = 0
      var b: UInt8 = 0

      _ = withUnsafeMutableBytes(of: &x) { data.copyBytes(to: $0, from: 0..<8) }
      _ = withUnsafeMutableBytes(of: &y) { data.copyBytes(to: $0, from: 8..<16) }
      _ = withUnsafeMutableBytes(of: &z) { data.copyBytes(to: $0, from: 16..<24) }

      r = data[24]
      g = data[25]
      b = data[26]

      // Convert Double to Float for SCNVector3:
      vertices.append(SCNVector3(Float(x), Float(y), Float(z)))
      colors.append(SCNVector3(Float(r) / 255, Float(g) / 255, Float(b) / 255))
    }

    // Optional: parse faces if needed (here we skip it for point cloud)

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

    // Create a dummy index buffer to draw as points
    var indices = Array(0..<Int32(vertices.count))
    let indexData = Data(bytes: &indices, count: MemoryLayout<Int32>.stride * indices.count)
    let element = SCNGeometryElement(
      data: indexData,
      primitiveType: .point,
      primitiveCount: indices.count,
      bytesPerIndex: MemoryLayout<Int32>.stride)

    let rootNode = SCNNode()

    for (i, vertex) in vertices.enumerated() {
      let sphere = SCNSphere(radius: 0.01)  // Adjust radius for desired size
      sphere.firstMaterial?.diffuse.contents = UIColor(
        red: CGFloat(colors[i].x),
        green: CGFloat(colors[i].y),
        blue: CGFloat(colors[i].z),
        alpha: 1.0
      )
      let sphereNode = SCNNode(geometry: sphere)
      sphereNode.position = SCNVector3(
        vertex.x - center.x,
        vertex.y - center.y,
        vertex.z - center.z
      )
      rootNode.addChildNode(sphereNode)
    }

    // Compute max distance from center
    var maxDistSquared: Float = 0
    for v in vertices {
      let dx = v.x - center.x
      let dy = v.y - center.y
      let dz = v.z - center.z
      maxDistSquared = max(maxDistSquared, dx * dx + dy * dy + dz * dz)
    }
    print("First 5 vertices:")
    for i in 0..<min(5, vertices.count) {
      print(vertices[i])
    }

    let maxRadius = sqrt(maxDistSquared)

    // Decide your target radius in scene units—e.g. 0.5
    let targetRadius: Float = 0.5
    let scale = targetRadius / maxRadius
    rootNode.scale = SCNVector3(scale, scale, scale)

    return rootNode
  }

}

// MARK: - UIViewRepresentable to wrap SCNView and display the node
struct SCNViewWrapper: UIViewRepresentable {
  let node: SCNNode

  func makeUIView(context: Context) -> SCNView {
    let scnView = SCNView()
    let scene = SCNScene()
    scene.rootNode.addChildNode(node)

    // Camera setup
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(-0.2, 0, 1)
    scene.rootNode.addChildNode(cameraNode)

    // Lights setup
    let lightNode = SCNNode()
    lightNode.light = SCNLight()
    lightNode.light!.type = .omni
    lightNode.position = SCNVector3(0, 10, 10)
    scene.rootNode.addChildNode(lightNode)

    let ambientLight = SCNNode()
    ambientLight.light = SCNLight()
    ambientLight.light!.type = .ambient
    ambientLight.light!.color = UIColor(white: 0.75, alpha: 1)
    scene.rootNode.addChildNode(ambientLight)

    scnView.scene = scene
    scnView.allowsCameraControl = true
    scnView.backgroundColor = .white

    return scnView
  }

  func updateUIView(_ uiView: SCNView, context: Context) {
    // No dynamic update needed currently
  }
}
