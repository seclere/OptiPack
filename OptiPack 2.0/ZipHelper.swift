//
//  ZipHelper.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 5/18/25.
//

// In your app target
import Foundation
import ZIPFoundation

class ZipHelper {
  static func zipPLYFile(at plyURL: URL, in documentsDirectory: URL) throws -> URL {
    let zipFileName = plyURL.deletingPathExtension().lastPathComponent + ".zip"
    let zipURL = documentsDirectory.appendingPathComponent(zipFileName)

    // Remove existing ZIP if needed
    if FileManager.default.fileExists(atPath: zipURL.path) {
      try FileManager.default.removeItem(at: zipURL)
    }

    // Zip the file
    try FileManager.default.zipItem(at: plyURL, to: zipURL)
    print("File exists: \(FileManager.default.fileExists(atPath: zipURL.path))")
    return zipURL
  }
}
