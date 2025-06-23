import ModelIO
import SceneKit
import SceneKit.ModelIO
import SwiftData
import SwiftUI

class ThumbnailCache: ObservableObject {
  static let shared = ThumbnailCache()
  @Published var images: [String: UIImage] = [:]  // Key: plyFileName
}

struct ItemScanThumbnailView: View {
  @Bindable var item: Item
  @State private var showEditor = false
  @Binding var source: String
  @State private var modelImage: UIImage?
  @ObservedObject private var cache = ThumbnailCache.shared

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      if let image = modelImage {
        ZStack {
          Color(hex: "EFF0F3")
          Image(uiImage: image)
            .resizable()
            .frame(width: 115, height: 150)
            .clipped()
        }
      } else {
        Color(hex: "EFF0F3")
      }

      VStack(alignment: .trailing, spacing: 2) {
        Spacer()
        VStack(alignment: .trailing, spacing: -1) {
          Text(item.details?.itemName ?? "Unnamed")
            .font(.system(size: 13))
            .foregroundColor(.black)
          Text(item.details?.itemCategory.rawValue ?? "")
            .font(.system(size: 10))
            .foregroundColor(.gray)
        }
        .padding(10)
      }
    }
    .frame(width: 115, height: 150)
    .cornerRadius(10)
    .onTapGesture {
      showEditor = true
    }
    .sheet(isPresented: $showEditor) {
      if source == "ItemTab" {
        EditItemScanView(scan: item.details!)
      }

      if source == "HomeTab" {
        InvEditItemScanView(scan: item.details!)
      }
    }
    .onAppear {
      loadThumbnailIfNeeded()
    }
  }

  private func loadThumbnailIfNeeded() {
    guard let key = item.plyFileName else { return }
    if let cached = cache.images[key] {
      self.modelImage = cached
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      if let scene = loadPLYScene(fileName: key),
        let thumbnail = generateThumbnail(from: scene)
      {
        DispatchQueue.main.async {
          self.modelImage = thumbnail
          cache.images[key] = thumbnail
        }
      }
    }
  }

  func generateThumbnail(from scene: SCNScene, size: CGSize = CGSize(width: 115, height: 150))
    -> UIImage?
  {
    let scnView = SCNView(frame: CGRect(origin: .zero, size: size))
    scnView.scene = scene

    // --- Add camera node ---
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(x: 1, y: 1, z: 1)
    let lookAt = SCNLookAtConstraint(target: scene.rootNode)
    lookAt.isGimbalLockEnabled = true
    cameraNode.constraints = [lookAt]

    scene.rootNode.addChildNode(cameraNode)
    scnView.pointOfView = cameraNode

    scnView.layoutIfNeeded()
    return scnView.snapshot()
  }

  func loadPLYScene(fileName: String) -> SCNScene? {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let plyURL = documentsURL.appendingPathComponent(fileName)

    guard fileManager.fileExists(atPath: plyURL.path) else {
      print("PLY file not found at path: \(plyURL.path)")
      return nil
    }

    let asset = MDLAsset(url: plyURL)
    let object = asset.object(at: 0)
    let scene = SCNScene()
    let node = SCNNode(mdlObject: object)
    scene.rootNode.addChildNode(node)

    return scene
  }
}
