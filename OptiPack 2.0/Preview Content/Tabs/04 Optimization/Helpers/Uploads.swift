//
//  Uploads.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/25/25.
//

import SwiftUI
import SwiftUICore
import _SwiftData_SwiftUI

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
