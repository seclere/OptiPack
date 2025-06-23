//
//  ZIPFunctions.swift
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

struct ZIPLoaders {

  @EnvironmentObject var authManager: AuthManager
  @State private var selectedPLYURL: URL?
  @State private var selectedPLYURLs: [URL] = []

  func createZipWithPLYsAndDimensions(width: Double, length: Double, height: Double) {
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
    let exportFolder = tempDir.appendingPathComponent("simulation_input")

    // 🧹 Clean old export folder
    try? fileManager.removeItem(at: exportFolder)
    do {
      try fileManager.createDirectory(at: exportFolder, withIntermediateDirectories: true)
      print("📁 Created export folder at: \(exportFolder.path)")
    } catch {
      print("❌ Failed to create export folder: \(error)")
      return
    }

    // 📝 Write container_dimensions.txt
    let textContent = "[ \(width) \(length) \(height) ]"
    let textURL = exportFolder.appendingPathComponent("container_dimensions.txt")
    do {
      try textContent.write(to: textURL, atomically: true, encoding: .utf8)
      print("✅ Wrote container_dimensions.txt to: \(textURL.path)")
    } catch {
      print("❌ Failed to write container_dimensions.txt: \(error)")
      return
    }

    // 📂 Copy selected .ply files to export folder
    for plyURL in selectedPLYURLs {
      let dest = exportFolder.appendingPathComponent(plyURL.lastPathComponent)
      do {
        try fileManager.copyItem(at: plyURL, to: dest)
        print("✅ Copied \(plyURL.lastPathComponent)")
      } catch {
        print("❌ Failed to copy \(plyURL.lastPathComponent): \(error)")
      }
    }

    // 🔍 Confirm export folder contents
    do {
      let files = try fileManager.contentsOfDirectory(atPath: exportFolder.path)
      print("📦 Export folder contents before zip: \(files)")
    } catch {
      print("❌ Could not list export folder contents: \(error)")
    }

    // 📦 Create ZIP
    let zipURL = tempDir.appendingPathComponent("PLYExport_\(UUID().uuidString.prefix(6)).zip")
    do {
      try fileManager.zipItem(at: exportFolder, to: zipURL)
      print("✅ ZIP created at: \(zipURL.lastPathComponent)")

      // 🚀 Automatically upload the zip
      uploadPointCloud(fileURL: zipURL)

    } catch {
      print("❌ Zipping failed: \(error)")
    }
  }

  func unzipFile(at zipURL: URL, to destinationURL: URL) {
    do {
      try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: zipURL, to: destinationURL)
      print("✅ Successfully unzipped to: \(destinationURL.path)")
    } catch {
      print("❌ Unzipping failed: \(error)")
    }
  }

  func uploadPointCloud(fileURL: URL) {
    let base = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    let meshingPath = UserDefaults.standard.string(forKey: "meshingPath") ?? "/meshing"
    let packingPath = UserDefaults.standard.string(forKey: "packingPath") ?? "/packing"

    let fullMeshingURLString =
      base.hasSuffix("/") || meshingPath.hasPrefix("/")
      ? base + meshingPath
      : base + "/" + meshingPath

    guard let serverURL = URL(string: fullMeshingURLString) else {
      print("❌ Invalid full packing URL")
      return
    }

    var request = URLRequest(url: serverURL)
    request.httpMethod = "POST"

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    let filename = fileURL.lastPathComponent
    let mimeType = "application/octet-stream"

    guard let fileData = try? Data(contentsOf: fileURL) else {
      print("❌ Failed to read file data")
      return
    }

    // Construct multipart body
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append(
      "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(
        using: .utf8)!)
    body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
    body.append(fileData)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    let task = URLSession.shared.uploadTask(with: request, from: body) {
      responseData, response, error in
      if let error = error {
        print("❌ Upload error: \(error)")
        return
      }

      guard let responseData = responseData else {
        print("❌ No data received from server")
        return
      }

      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let zipURL = documents.appendingPathComponent("processed_result.zip")

      do {
        try responseData.write(to: zipURL)
        print("✅ ZIP saved at: \(zipURL.path)")

        let unzipDestination = documents.appendingPathComponent("AlgoResult")
        self.unzipFile(at: zipURL, to: unzipDestination)

        // Unzip using Foundation Archive
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
          print("❌ Could not open ZIP archive")
          return
        }

        for entry in archive {
          let outputURL = unzipDestination.appendingPathComponent(entry.path)
          _ = try archive.extract(entry, to: outputURL)
          print("✅ Extracted: \(entry.path)")
        }

        print("✅ All files extracted to: \(unzipDestination.path)")

      } catch {
        print("❌ Error saving or unzipping ZIP: \(error)")
      }
    }

    task.resume()
  }

  func exportInventoryToZip(inventory: Inventory) -> URL? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let unzippedPLYFolder = documentsURL.appendingPathComponent("UnzippedPLY")
    let exportFolder = documentsURL.appendingPathComponent("simulation_input")

    try? fileManager.removeItem(at: exportFolder)
    try? fileManager.createDirectory(at: exportFolder, withIntermediateDirectories: true)

    for item in inventory.items {
      let source = unzippedPLYFolder.appendingPathComponent(item.plyFileName ?? "bonk")
      let dest = exportFolder.appendingPathComponent(item.plyFileName ?? "bonk")
      if fileManager.fileExists(atPath: source.path) {
        try? fileManager.copyItem(at: source, to: dest)
      } else {
        print("⚠️ Missing file for \(item.label): \(item.plyFileName)")
      }
    }

    let zipURL = documentsURL.appendingPathComponent("Exported_\(inventory.inventoryName).zip")
    try? fileManager.removeItem(at: zipURL)
    do {
      try fileManager.zipItem(at: exportFolder, to: zipURL)
      print("✅ Zipped: \(zipURL.lastPathComponent)")
      return zipURL
    } catch {
      print("❌ Zip failed: \(error)")
      return nil
    }
  }

}
