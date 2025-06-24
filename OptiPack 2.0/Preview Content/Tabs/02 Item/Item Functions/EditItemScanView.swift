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
  @State private var showConfirmationAlert = false
  @State private var isEditing = false
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var authManager: AuthManager
  @Query private var allInventories: [Inventory]
  @State private var showInventoryPicker = false
  @State private var selectedInventoryIndex: Int? = nil
  @State private var showPLYViewer = false

  let PLYLoader = PLYLoaders()

  private var inventories: [Inventory] {
    guard let cluster = authManager.currentUser?.inventoryCluster else { return [] }
    return allInventories.filter { cluster.inventories.contains($0) }
  }

  private var plyFileURL: URL? {
    guard let plyFileName = plyFileName else { return nil }
    return Bundle.main.url(
      forResource: plyFileName.replacingOccurrences(of: ".ply", with: ""), withExtension: "ply")
  }

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
                  PLYLoader.loadSceneFromPLY(at: url)
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
