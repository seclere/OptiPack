// Team Differential || OptiPack 2.0 || OptimizationTab.swift

// COMPREHENSIVE DESCRIPTION:
// The Optimization Tab is where the main work happens.
// This is where the user can define the size of their container,
// as well as select which Inventory they wish to include into the
// container.
// More importantly, this is where the final optimization is displayed
// for the user to view.

import Foundation
import QuartzCore
import SceneKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

extension UTType {
  static var ply: UTType {
    UTType(filenameExtension: "ply") ?? .data
  }
}

struct OptimizationTab: View {

  @EnvironmentObject var authManager: AuthManager

  @State private var containerWidth = ""
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

  let PLYLoader = PLYLoaders()
  let ZIPLoader = ZIPLoaders()

  var body: some View {

    ZStack {
      VStack(spacing: 10) {
        if let loadedScene = scene {
          ZStack(alignment: .topTrailing) {
            SceneView(
              scene: loadedScene,
              pointOfView: nil,
              options: [.allowsCameraControl, .autoenablesDefaultLighting],
              preferredFramesPerSecond: 60,
              antialiasingMode: .multisampling4X,
              delegate: nil,
              technique: nil
            )
            .frame(height: 670)
            .background(Color.black)
            .cornerRadius(12)

            Button(action: {
              scene = nil
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.teal)
                .padding(8)
            }
            .padding(12)
          }
        } else {
          Text("No PLY loaded.")
            .frame(height: 350)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            .foregroundColor(.white)
        }

        Button("Import PLY File") {
          isFileImporterPresented = true
        }
        .fileImporter(
          isPresented: $isFileImporterPresented,
          allowedContentTypes: [.item],
          allowsMultipleSelection: false
        ) { result in
          switch result {
          case .success(let urls):
            if let url = urls.first {
              selectedPLYURL = url
              PLYLoader.loadSceneFromPLY(at: url)
            }
          case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
          }
        }

        Spacer()
      }

      Rectangle()
        .fill(Color(hex: "1E1E1E"))
        .frame(width: 550, height: isOpen ? 220 : 180)
        .position(x: 201, y: 870)

      VStack {
        Capsule()
          .frame(width: 140, height: 6)
          .alignmentGuide(.bottom) { $0[VerticalAlignment.bottom] }
          .foregroundColor(.gray)
          .padding(.top, 10)

        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 20) {

            // INVENTORY SECTION
            HStack {
              Text("Optimized Inventories")
                .font(.system(size: 25))
                .foregroundColor(.white)
            }
            .fontWeight(.bold)
            .frame(maxWidth: 380, alignment: .leading)
            .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 15) {

                if let user = authManager.currentUser {
                  OptimizationInventoryGalleryView(
                    selectedCategory: selectedCategory,
                    searchText: searchInput, user: user)
                } else {
                  Text("Please sign in to view your inventories.")
                    .foregroundColor(.gray)
                }

              }
            }
            .frame(maxWidth: 380, maxHeight: 180, alignment: .center)

            Button("Export") {
              isMultiplePLYImporterPresented = true
            }
            .fileImporter(
              isPresented: $isMultiplePLYImporterPresented,
              allowedContentTypes: [.item],
              allowsMultipleSelection: true
            ) { result in
              switch result {
              case .success(let urls):
                selectedPLYURLs = urls
                showDimensionPrompt = true
              case .failure(let error):
                print("❌ File import failed: \(error)")
              }
            }

            if showDimensionPrompt {
              Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showDimensionPrompt = false }

              VStack(spacing: 20) {
                Text("Enter Container Dimensions")
                  .font(.headline)

                TextField("Width", text: $widthInput)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .keyboardType(.decimalPad)

                TextField("Length", text: $lengthInput)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .keyboardType(.decimalPad)

                TextField("Height", text: $heightInput)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .keyboardType(.decimalPad)

                HStack {
                  Button("Cancel") {
                    showDimensionPrompt = false
                  }
                  .foregroundColor(.red)

                  Button("Create ZIP") {
                    if let width = Double(widthInput),
                      let length = Double(lengthInput),
                      let height = Double(heightInput)
                    {
                      ZIPLoader.createZipWithPLYsAndDimensions(
                        width: width, length: length, height: height)
                      showDimensionPrompt = false
                    } else {
                      print("❌ Invalid input")
                    }
                  }
                  .padding()
                  .background(Color.blue)
                  .foregroundColor(.white)
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                }
              }
              .padding()
              .frame(maxWidth: 300)
              .background(Color(.systemBackground))
              .cornerRadius(12)
              .shadow(radius: 10)
            }

            // MARK: tentative area to upload data
            Button(action: {
              withAnimation {
                showUploadPopup = true
                print("UPLOAD BUTTON PRESSED")
              }
              //uploadContainerAndPLYs($containerWidth, $containerHeight, $containerDepth, $containerMaximumWeight)
            }) {
              Label("Upload Data", systemImage: "arrow.up.circle.fill")
                .padding()
                .frame(maxWidth: 360)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 4)
            }
            .padding(.top, 10)

            Spacer()
          }
          Spacer()
        }
        .padding(.top, 15)
        .toolbar {
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
              UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
          }
        }
      }
      .frame(maxWidth: 420, maxHeight: 550)
      .padding(.horizontal, 20)
      .background(Color(hex: "1E1E1E"))
      .cornerRadius(40)
      .offset(y: offsetY)
      .gesture(
        DragGesture()
          .onChanged { value in
            let proposedOffset = value.translation.height + offsetY

            if offsetY >= closedPosition && value.translation.height > 0 {
              return  // block downward drag
            }

            // Normal drag range
            if proposedOffset >= openPosition && proposedOffset <= UIScreen.main.bounds.height {
              offsetY = proposedOffset
            }
          }
          .onEnded { value in
            withAnimation {
              if value.translation.height > 100 {
                offsetY = closedPosition  // snap closed
                isOpen = false
              } else {
                offsetY = openPosition  // snap open
                isOpen = true
              }
            }
          }
      )
      .animation(.easeInOut, value: offsetY)

      if showUploadPopup {
        UploadPopupView(showUploadPopup: $showUploadPopup) {
        }
      }
    }
  }

  // MARK: - Field Helper
  func field(_ label: String, value: Binding<String>, unit: Binding<String>) -> some View {
    VStack(alignment: .leading) {
      Text(label)
        .frame(maxWidth: 350, maxHeight: 35, alignment: .leading)
        .font(.system(size: 16))
        .fontWeight(.semibold)
        .foregroundColor(.white)

      ZStack(alignment: .trailing) {
        TextField("", text: value)
          .frame(maxWidth: 130, maxHeight: 35, alignment: .leading)
          .padding(.leading, 10)
          .foregroundColor(.black)
          .background(.white)
          .cornerRadius(6)
          .keyboardType(.decimalPad)

        Picker("", selection: unit) {
          ForEach(measurementUnits, id: \.self) { unit in
            Text(unit).tag(unit)
          }
        }
        .pickerStyle(MenuPickerStyle())
        .background(.white)
        .frame(width: 65, height: 35)
        .padding(.trailing, -5)
        .cornerRadius(6)
      }
    }
  }
}

struct UploadPopupView: View {

  @State private var containerselectedPLYFiles: [URL] = []

  @State private var containerWidth: Double = 0.0
  @State private var containerHeight: Double = 0.0
  @State private var containerDepth: Double = 0.0
  @State private var containerMaximumWeight: Double = 0.0

  private var numberFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
  }

  @State private var selectedMeasurementUnit: String = "in"
  @State private var selectedWeightUnit: String = "kg"
  let measurementUnits = ["in", "cm"]
  let weightUnits = ["kg", "lbs"]

  @State private var selectedInventoryIndex: Int? = nil

  @EnvironmentObject var authManager: AuthManager

  @Query private var allInventories: [Inventory]

  private var inventories: [Inventory] {
    guard let cluster = authManager.currentUser?.inventoryCluster else { return [] }
    return allInventories.filter { cluster.inventories.contains($0) }
  }

  @Binding var showUploadPopup: Bool
  var onConfirm: () -> Void

  func createContainerTextFile(width: Double, height: Double, depth: Double) -> URL? {
    let text = "Width: \(width)\nHeight: \(height)\nDepth: \(depth)"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "container_dimensions.txt")

    do {
      try text.write(to: fileURL, atomically: true, encoding: .utf8)
      print("CreateContainerTextFile: Successfully written")
      return fileURL
    } catch {
      print("❌ Failed to write container_dimensions.txt: \(error)")
      return nil
    }
  }

  func createMultipartBody(boundary: String, jsonFile: URL, plyFiles: [URL]) -> Data {
    var body = Data()

    // Add JSON metadata
    if let jsonData = try? Data(contentsOf: jsonFile) {
      body.append("--\(boundary)\r\n")
      body.append(
        "Content-Disposition: form-data; name=\"metadata\"; filename=\"\(jsonFile.lastPathComponent)\"\r\n"
      )
      body.append("Content-Type: application/json\r\n\r\n")
      body.append(jsonData)
      body.append("\r\n")
    }

    // Add PLY files
    for fileURL in plyFiles {
      guard let fileData = try? Data(contentsOf: fileURL) else { continue }
      body.append("--\(boundary)\r\n")
      body.append(
        "Content-Disposition: form-data; name=\"plyFiles\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
      )
      body.append("Content-Type: application/octet-stream\r\n\r\n")
      body.append(fileData)
      body.append("\r\n")
    }

    body.append("--\(boundary)--\r\n")
    return body
  }

  func uploadContainerAndPLYs() {
    // 1. Create JSON metadata file
    let containerData = [
      "width": containerWidth,
      "height": containerHeight,
      "depth": containerDepth,
      "maxWeight": containerMaximumWeight,
    ]

    guard
      let jsonData = try? JSONSerialization.data(
        withJSONObject: containerData, options: .prettyPrinted)
    else {
      print("Failed to serialize container data")
      return
    }

    let jsonFilename = "containerMetadata.json"
    let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent(jsonFilename)

    do {
      try jsonData.write(to: jsonURL)
    } catch {
      print("Failed to write container metadata JSON: \(error)")
      return
    }

    print("Metadata JSON written to: \(jsonURL)")

    // 2. Prepare multipart upload
    let boundary = "Boundary-\(UUID().uuidString)"
    var request = URLRequest(url: URL(string: "https://your.api/upload")!)  // 🔁 Replace with real URL
    request.httpMethod = "POST"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    let body = createMultipartBody(
      boundary: boundary,
      jsonFile: jsonURL,
      plyFiles: containerselectedPLYFiles
    )

    URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
      if let error = error {
        print("Upload failed: \(error)")
      } else {
        print("Upload successful")
      }
    }.resume()
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.25).ignoresSafeArea()
        .onTapGesture {
          withAnimation {
            showUploadPopup = false
          }
        }

      VStack(spacing: 16) {
        Text("Upload Confirmation")
          .font(.headline)
          .padding(.top)

        HStack {

          VStack {
            VStack(alignment: .leading) {
              Text("Width")
                .frame(maxWidth: 350, maxHeight: 35, alignment: .leading)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.white)

              ZStack(alignment: .trailing) {
                TextField("Width", value: $containerWidth, formatter: numberFormatter)
                  .keyboardType(.decimalPad)
                  .frame(maxWidth: 130, maxHeight: 35, alignment: .leading)
                  .padding(.leading, 10)
                  .foregroundColor(.black)
                  .background(.white)
                  .cornerRadius(6)
                  .keyboardType(.decimalPad)

                Picker("", selection: $selectedMeasurementUnit) {
                  ForEach(measurementUnits, id: \.self) { unit in
                    Text(unit).tag(unit)
                  }
                }
                .pickerStyle(MenuPickerStyle())
                .background(.white)
                .frame(width: 65, height: 35)
                .padding(.trailing, -5)
                .cornerRadius(6)
              }
            }

            VStack(alignment: .leading) {
              Text("Height")
                .frame(maxWidth: 350, maxHeight: 35, alignment: .leading)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.white)

              ZStack(alignment: .trailing) {
                TextField("Height", value: $containerHeight, formatter: numberFormatter)
                  .keyboardType(.decimalPad)
                  .frame(maxWidth: 130, maxHeight: 35, alignment: .leading)
                  .padding(.leading, 10)
                  .foregroundColor(.black)
                  .background(.white)
                  .cornerRadius(6)
                  .keyboardType(.decimalPad)

                Picker("", selection: $selectedMeasurementUnit) {
                  ForEach(measurementUnits, id: \.self) { unit in
                    Text(unit).tag(unit)
                  }
                }
                .pickerStyle(MenuPickerStyle())
                .background(.white)
                .frame(width: 65, height: 35)
                .padding(.trailing, -5)
                .cornerRadius(6)
              }
            }

            VStack(alignment: .leading) {
              Text("Depth")
                .frame(maxWidth: 350, maxHeight: 35, alignment: .leading)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.white)

              ZStack(alignment: .trailing) {
                TextField("Depth", value: $containerDepth, formatter: numberFormatter)
                  .keyboardType(.decimalPad)
                  .frame(maxWidth: 130, maxHeight: 35, alignment: .leading)
                  .padding(.leading, 10)
                  .foregroundColor(.black)
                  .background(.white)
                  .cornerRadius(6)
                  .keyboardType(.decimalPad)

                Picker("", selection: $selectedMeasurementUnit) {
                  ForEach(measurementUnits, id: \.self) { unit in
                    Text(unit).tag(unit)
                  }
                }
                .pickerStyle(MenuPickerStyle())
                .background(.white)
                .frame(width: 65, height: 35)
                .padding(.trailing, -5)
                .cornerRadius(6)
              }
            }
          }

          VStack(alignment: .leading) {
            Text("Maximum Weight Capacity")
              .font(.system(size: 16))
              .fontWeight(.semibold)
              .foregroundColor(.white)
              .frame(maxWidth: 350, alignment: .leading)
              .multilineTextAlignment(.leading)
              .lineLimit(nil)
              .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .trailing) {
              TextField("Max Weight", value: $containerMaximumWeight, formatter: numberFormatter)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 150, maxHeight: 35, alignment: .leading)
                .padding(.leading, 10)
                .foregroundColor(.black)
                .background(.white)
                .cornerRadius(6)
                .keyboardType(.decimalPad)

              Picker("", selection: $selectedWeightUnit) {
                ForEach(weightUnits, id: \.self) { unit in
                  Text(unit).tag(unit)
                }
              }
              .pickerStyle(MenuPickerStyle())
              .background(.white)
              .frame(width: 65, height: 35)
              .padding(.trailing, -5)
              .cornerRadius(6)
            }

          }
        }

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
            selectedInventoryIndex = nil
          }
        }

        HStack(spacing: 20) {
          Button("Cancel") {
            withAnimation {
              showUploadPopup = false
            }
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.gray.opacity(0.2))
          .clipShape(RoundedRectangle(cornerRadius: 10))

          Button("Upload") {
            print("Upload Button Pressed")
            createContainerTextFile(
              width: containerWidth, height: containerHeight, depth: containerDepth)
            withAnimation {
              showUploadPopup = false
            }
            onConfirm()
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.teal)
          .foregroundColor(.white)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding([.horizontal, .bottom])
      }
      .frame(width: 300)
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .shadow(radius: 10)
    }
  }
}

extension Data {
  mutating func append(_ string: String) {
    if let data = string.data(using: .utf8) {
      append(data)
    }
  }
}

#Preview {
  OptimizationTab()
}
