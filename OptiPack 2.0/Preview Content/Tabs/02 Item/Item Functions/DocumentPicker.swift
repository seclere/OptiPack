import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
  @Binding var fileURL: URL?

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    print("makeUIViewController called")
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
    picker.delegate = context.coordinator
    picker.allowsMultipleSelection = false
    return picker
  }

  func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context)
  {}

  class Coordinator: NSObject, UIDocumentPickerDelegate {
    let parent: DocumentPicker

    init(_ parent: DocumentPicker) {
      self.parent = parent
    }

    func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      guard let url = urls.first else { return }

      print("Picked URL: \(url)")

      // Try to read the file directly without security scope:
      do {
        let data = try Data(contentsOf: url)
        print("File data loaded, size: \(data.count) bytes")
      } catch {
        print("Error reading file directly: \(error.localizedDescription)")
      }

      // Now copy it into Documents folder:
      let fileManager = FileManager.default
      let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let destURL = docsURL.appendingPathComponent(url.lastPathComponent)

      do {
        if fileManager.fileExists(atPath: destURL.path) {
          try fileManager.removeItem(at: destURL)
        }
        try fileManager.copyItem(at: url, to: destURL)
        print("Copied file to \(destURL)")

        DispatchQueue.main.async {
          self.parent.fileURL = destURL
        }
      } catch {
        print("Error copying file: \(error.localizedDescription)")
      }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      // Optional: handle cancel
    }
  }
}
