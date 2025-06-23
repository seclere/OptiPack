import Foundation
import SceneKit
import SwiftData
//
//  JSONLoader.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/23/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct JSONLoaders {

  var jsonCandidates: [JSONCandidate] = []

  func decodeJSONItems(from url: URL) -> [ItemData]? {
    do {
      let data = try Data(contentsOf: url)
      let items = try JSONDecoder().decode([ItemData].self, from: data)
      return items
    } catch {
      print("Error decoding JSON: \(error)")
      return nil
    }
  }

  func createItemFromMetadataJSON(
    jsonURL: URL, plyFileName: String, user: UserCredentials, context: ModelContext
  ) -> Item? {
    do {
      let jsonData = try Data(contentsOf: jsonURL)
      let decoded = try JSONDecoder().decode([ItemData].self, from: jsonData)

      guard let metadata = decoded.first else {
        print("JSON does not contain any items.")
        return nil
      }

      print("Category from JSON: \(metadata.category)")  // Corrected string interpolation

      guard let category = fixedCategory(rawValue: metadata.category.capitalized) else {
        print("Invalid category string: \(metadata.category)")
        return nil
      }

      let defaultWidth: Float = 0.1
      let defaultDepth: Float = 0.1
      let defaultHeight: Float = 0.1
      let defaultWeight: Float = 0.1
      let defaultAngles: [Float] = [0.0]

      let details = ItemDetails(
        itemName: metadata.type,
        itemCategory: category,
        width: defaultWidth,
        depth: defaultDepth,
        height: defaultHeight,
        weight: defaultWeight,
        allowedAngles: defaultAngles,
        stackable: metadata.stackable,
        fragile: metadata.fragile
      )

      let item = Item(
        label: metadata.type,
        plyFileName: plyFileName,
        details: details,
        user: user
      )

      details.item = item

      // Insert both to context to be safe
      context.insert(details)
      context.insert(item)
      try context.save()

      return item
    } catch {
      print("Failed to parse JSON or create item: \(error)")  // Corrected string interpolation
      return nil
    }
  }

  func injectJSONMetadataIntoBinaryPLY(plyURL: URL, jsonMetadata: [String: Any], outputURL: URL)
    throws
  {
    // 1. Open file handle for reading
    let fileHandle = try FileHandle(forReadingFrom: plyURL)
    defer { try? fileHandle.close() }

    // 2. Read header text and size (bytes)
    let (headerText, headerSize) = try readPLYHeader(from: fileHandle)

    // 3. Prepare comment lines from JSON metadata
    let jsonData = try JSONSerialization.data(
      withJSONObject: jsonMetadata, options: [.prettyPrinted])
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw NSError(
        domain: "PLY", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON metadata string"])
    }
    let commentLines =
      jsonString
      .components(separatedBy: .newlines)
      .map { "comment \($0)" }
      .joined(separator: "\n") + "\n"

    // 4. Insert comment lines just before "end_header"
    let modifiedHeader = headerText.replacingOccurrences(
      of: "end_header", with: commentLines + "end_header")

    guard let modifiedHeaderData = modifiedHeader.data(using: .ascii) else {
      throw NSError(
        domain: "PLY", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode modified header"])
    }

    // 5. Open the PLY file again (or reset) to read the binary body after the header
    let fullFileData = try Data(contentsOf: plyURL)
    let bodyData = fullFileData.subdata(in: headerSize..<fullFileData.count)

    // 6. Combine modified header + original binary body
    var newFileData = Data()
    newFileData.append(modifiedHeaderData)
    newFileData.append(bodyData)

    // 7. Write to output file
    try newFileData.write(to: outputURL)

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

    func downloadProcessedFile(filename: String) {
      let base = UserDefaults.standard.string(forKey: "serverURL") ?? ""

      // Force the download URL to use the .zip version of the filename
      let zipFilename = (filename as NSString).deletingPathExtension + ".zip"
      let downloadPath = "/download/\(zipFilename)"

      let fullDownloadURLString =
        base.hasSuffix("/") || downloadPath.hasPrefix("/")
        ? base + downloadPath
        : base + "/" + downloadPath

      print("📥 Starting download for: \(zipFilename)")

      guard let fileDownloadURL = URL(string: fullDownloadURLString) else {
        print("❌ Invalid file download URL")
        return
      }

      let task = URLSession.shared.downloadTask(with: fileDownloadURL) {
        localURL, response, error in
        if let error = error {
          print("Download error: \(error)")
          return
        }

        guard let localURL = localURL else {
          print("Download failed: no URL")
          return
        }

        do {
          let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          let destinationURL = documents.appendingPathComponent(zipFilename)

          if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
          }

          try FileManager.default.moveItem(at: localURL, to: destinationURL)
          print("✅ File saved to: \(destinationURL.path)")
        } catch {
          print("❌ Error saving file: \(error)")
        }
      }

      task.resume()
    }
  }

}

class JSONStateModels: ObservableObject {
  @Published var jsonCandidates: [JSONCandidate] = []

  func buildJSONCandidatesFromDownloads() {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let objectsDetectedURL = documentsURL.appendingPathComponent("ObjectsDetected")

    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: objectsDetectedURL, includingPropertiesForKeys: nil)
      let jsonFiles = fileURLs.filter { $0.pathExtension.lowercased() == "json" }

      let candidates = jsonFiles.compactMap { url -> JSONCandidate? in
        do {
          let data = try Data(contentsOf: url)
          let raw = try JSONSerialization.jsonObject(with: data)

          if let array = raw as? [[String: Any]],
            let first = array.first,
            let label = first["type"] as? String
          {
            return JSONCandidate(label: label, url: url)
          } else {
            print("⚠️ Invalid format in \(url.lastPathComponent)")
            return nil
          }
        } catch {
          print("❌ Error reading JSON from \(url): \(error)")
          return nil
        }
      }

      DispatchQueue.main.async {
        self.jsonCandidates = candidates
      }

      print("✅ Found \(candidates.count) JSON metadata files in ObjectsDetected")

    } catch {
      print("❌ Failed to read ObjectsDetected folder: \(error)")
    }
  }
}
