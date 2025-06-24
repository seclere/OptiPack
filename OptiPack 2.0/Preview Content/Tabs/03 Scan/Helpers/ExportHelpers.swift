//  ExportHelpers.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/24/25.
//

import Foundation
import UIKit

extension Renderer {
  public func savePointsToFile() {

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

    for i in 0..<currentPointCount {

      let point = particlesBuffer[i]
      let colors = point.color

      let red = Int(colors.x * 255.0).clamped(to: 0...255)
      let green = Int(colors.y * 255.0).clamped(to: 0...255)
      let blue = Int(colors.z * 255.0).clamped(to: 0...255)

      let pvValue =
        "\(point.position.x) \(point.position.y) \(point.position.z) \(Int(red)) \(Int(green)) \(Int(blue)) 255"
      fileToWrite += pvValue
      fileToWrite += "\r\n"
    }
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    let filename = "ply_\(UUID().uuidString).ply"
    let file = documentsDirectory.appendingPathComponent(filename)
    do {
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

}
