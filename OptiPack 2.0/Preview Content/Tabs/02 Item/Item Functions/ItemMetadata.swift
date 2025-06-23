import SwiftData
import SwiftUI

func readJSON(from url: URL) throws -> Any {
  let data = try Data(contentsOf: url)
  return try JSONSerialization.jsonObject(with: data, options: [])
}

func appendJSONMetadataToPLY(plyURL: URL, jsonURL: URL, outputURL: URL) throws {
  // 1. Read JSON data and parse it to Dictionary
  let jsonData = try Data(contentsOf: jsonURL)
  guard
    let array = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]],
    let metadata = array.first
  else {
    throw NSError(
      domain: "JSONError", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Expected array of dictionaries"])
  }

  // 2. Format JSON as pretty printed string, then prefix lines with "comment "
  let jsonDataPretty = try JSONSerialization.data(
    withJSONObject: metadata, options: [.prettyPrinted])
  guard let jsonString = String(data: jsonDataPretty, encoding: .utf8) else {
    throw NSError(
      domain: "PLY", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to stringify JSON"])
  }
  let commentLines =
    jsonString
    .split(separator: "\n")
    .map { "comment \($0)" }
    .joined(separator: "\n")

  // 3. Read original PLY as string
  var plyString = try String(contentsOf: plyURL, encoding: .utf8)

  // 4. Find header end (line with "end_header") and header start (line with "ply" and "format")
  // Insert comment after format line

  // Split into lines
  var lines = plyString.components(separatedBy: .newlines)

  // Find index of format line
  guard let formatLineIndex = lines.firstIndex(where: { $0.starts(with: "format ") }) else {
    throw NSError(
      domain: "PLY", code: 2, userInfo: [NSLocalizedDescriptionKey: "No format line in PLY"])
  }

  // Insert comment lines after the format line
  lines.insert(
    contentsOf: commentLines.split(separator: "\n").map(String.init), at: formatLineIndex + 1)

  // 5. Join back all lines
  let newPLYString = lines.joined(separator: "\n")

  // 6. Save new PLY file
  try newPLYString.write(to: outputURL, atomically: true, encoding: .utf8)
}

func addJSONMetadataToPLY(plyURL: URL, jsonMetadata: [String: Any]) throws -> String {
  let plyContent = try String(contentsOf: plyURL, encoding: .utf8)
  var lines = plyContent.components(separatedBy: .newlines)

  // Find the index of the end_header line
  guard
    let endHeaderIndex = lines.firstIndex(where: {
      $0.trimmingCharacters(in: .whitespaces) == "end_header"
    })
  else {
    throw NSError(
      domain: "PLYError", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "PLY header missing end_header"])
  }

  // Serialize JSON metadata into pretty-printed string (indented)
  let jsonData = try JSONSerialization.data(withJSONObject: jsonMetadata, options: [.prettyPrinted])
  guard let jsonString = String(data: jsonData, encoding: .utf8) else {
    throw NSError(
      domain: "JSONError", code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Failed to stringify JSON"])
  }

  // Prepare comment lines from JSON string
  let commentLines =
    jsonString
    .components(separatedBy: .newlines)
    .map { "comment \($0)" }

  // Insert the comment lines just before "end_header"
  lines.insert(contentsOf: commentLines, at: endHeaderIndex)

  // Join lines back into one string
  return lines.joined(separator: "\n")
}

func saveModifiedPLY(content: String) throws -> URL {
  let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  let newFileURL = documents.appendingPathComponent("modified_\(UUID().uuidString).ply")
  try content.write(to: newFileURL, atomically: true, encoding: .utf8)
  return newFileURL
}
