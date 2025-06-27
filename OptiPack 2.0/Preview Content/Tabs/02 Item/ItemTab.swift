// Team Differential || OptiPack 2.0 || ItemTab.swift

// COMPREHENSIVE DESCRIPTION:
// This view serves as the catalogue of OptiPack.
// It displays all of the items that the user has scanned,
// allowing users to search, view, and manage their item details.
// Categories include Electronics, Food, Fragile, and Miscellaneous.

import Foundation
import SceneKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ItemTab: View {
  @EnvironmentObject var authManager: AuthManager
  @EnvironmentObject var notificationManager: NotificationManager
  @StateObject private var keyboardObserver = KeyboardObserver()
  @Environment(\.modelContext) private var context

  @Query private var users: [UserCredentials]

  @State private var searchText = ""
  @State private var sortAscending: Bool = true
  @State private var selectedCategory = "All"
  @State private var scanCount = 0
  @State private var showPopup = false
  @State private var selectedPlyFileURL: URL? = nil
  @State private var selectedJSONFileURL: URL? = nil
  @State private var isPickerPresented1 = false
  @State private var isPickerPresented2 = false
  @State private var previewPLYNode: SCNNode? = nil
  @State private var showPLYPreview: Bool = false
  @State private var decodedItems: [ItemData] = []
  @State private var pendingFilenames: [String] = []
  @State private var downloadedFiles: Set<String> = []
  @State var plyMatches: [PLYMatch] = []
  @State var jsonCandidates: [JSONCandidate] = []
  @State private var selectedPLYForPreview: PLYMatch? = nil

  let JSONLoader = JSONLoaders()

  var body: some View {
    NavigationView {
      ZStack {
        VStack(spacing: 15) {
          //HEADER ------------------------------------------------------------------------
          Text("Your Items")
            .frame(maxWidth: 380, alignment: .center)
            .fontWeight(.bold)
            .font(.system(size: 24))

          //CATEGORY SECTION ------------------------------------------------------------------------
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
              let categories = ["All", "Electronics", "Food", "Fragile", "Miscellaneous"]

              ForEach(categories, id: \.self) { category in
                Button(action: {
                  selectedCategory = category
                }) {
                  Text(category)
                    .foregroundColor(selectedCategory == category ? .primary : .gray)
                }
              }
            }
            .fontWeight(.semibold)
            .font(.system(size: 14))
          }
          .frame(maxWidth: 380, alignment: .center)

          //SEARCH BAR ------------------------------------------------------------------------
          HStack(spacing: 15) {
            HStack {
              Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "8F9195"))
              TextField("Search", text: $searchText).foregroundColor(.black)
              if !searchText.isEmpty {
                Button(action: {
                  searchText = ""
                }) {
                  Image(systemName: "xmark.circle.fill")
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "8F9195"))
                }.frame(maxWidth: 71, maxHeight: 35, alignment: .trailing)
              }
            }
            .frame(maxWidth: 320, maxHeight: 35, alignment: .center)
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .background(Color(hex: "EFF0F3"))
            .cornerRadius(6)

            Button(action: {
              sortAscending.toggle()
            }) {
              HStack(spacing: 0.5) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down").scaleEffect(
                  x: 0.7, y: 1.0)

                ZStack {
                  VStack(alignment: .leading, spacing: 2) {
                    Capsule().frame(width: 14, height: 2)
                    Capsule().frame(width: 11, height: 2)
                    Capsule().frame(width: 8, height: 2)
                    Capsule().frame(width: 5, height: 2)
                  }
                }
              }
              .scaleEffect(x: 1.2, y: 1.2)
              .foregroundColor(.primary)
            }
          }

          // ITEMS LIST ------------------------------------------------------------------------
          ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 15) {
              ItemScanListView(
                categ: selectedCategory,
                sortAscending: sortAscending,
                searchText: searchText
              )
            }
          }
          .frame(maxWidth: 400, maxHeight: .infinity)
          .padding(.top, 10)
          Spacer()

        }
        .padding(.top, 20)
        .padding(.horizontal, 20)

        // ADD BUTTON ------------------------------------------------------------------------
        VStack {
          Spacer()
          HStack {
            Spacer()
            Button(action: {
              withAnimation {
                showPopup = true
              }
            }) {
              Image(systemName: "plus")
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(.primary))
            }
            .padding()
            .padding(.horizontal, 20)
          }
        }

        // POP UP ------------------------------------------------------------------------
        if showPopup {
          MatchingPopupView(
            showPopup: $showPopup,
            user: authManager.currentUser!,
            context: context,
            plyMatches: $plyMatches,
            jsonCandidates: jsonCandidates,
            onComplete: {
              fetchPendingFilesOnce()
            }
          )
          .transition(.scale)
        }
      }
    }
    .onAppear {
      pendingFilenames = UserDefaults.standard.stringArray(forKey: "pendingPLYs") ?? []
    }
  }

  private func clearPopup() {
    withAnimation {
      selectedPlyFileURL = nil
      selectedJSONFileURL = nil
      showPopup = false
    }
  }

  func fetchPendingFilesOnce() {
    guard pendingFilenames.isEmpty else { return }

    let fileManager = FileManager.default
    let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

    do {
      let files = try fileManager.contentsOfDirectory(atPath: docsURL.path)
      let plyAndJsonFiles = files.filter { $0.hasSuffix(".ply") || $0.hasSuffix(".json") }

      let undownloaded = plyAndJsonFiles.filter { !downloadedFiles.contains($0) }
      pendingFilenames = Array(Set(undownloaded))
    } catch {
      print("Error reading documents directory: \(error)")
    }
  }

  func markAsDownloaded(filename: String) {
    downloadedFiles.insert(filename)
    pendingFilenames.removeAll { $0 == filename }
  }

}

struct PLYMatchRow: View {
  @Binding var match: PLYMatch
  let jsonCandidates: [JSONCandidate]
  let onTapPreview: () -> Void

  var previewScene: SCNScene? {
    guard let node = match.previewNode else { return nil }
    let scene = SCNScene()
    scene.rootNode.addChildNode(node.clone())
    return scene
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let scene = previewScene {
        SceneView(scene: scene, options: [.allowsCameraControl])
          .frame(height: 150)
          .cornerRadius(8)
          .onTapGesture {
            onTapPreview()
          }
      }

      Picker("Select description", selection: $match.matchedJSON) {
        Text("None").tag(JSONCandidate?.none)
        ForEach(jsonCandidates) { json in
          Text(json.label).tag(Optional(json))
        }
      }
      .pickerStyle(MenuPickerStyle())
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(10)
    .padding(.horizontal)
  }
}

struct MatchingPopupView: View {
  @Binding var showPopup: Bool
  var user: UserCredentials
  var context: ModelContext
  @Binding var plyMatches: [PLYMatch]
  @State var jsonCandidates: [JSONCandidate] = []
  var onComplete: () -> Void

  @State private var selectedPLYForPreview: PLYMatch?

  let JSONStateModel = JSONStateModels()
  let PLYStateModel = PLYStateModels()
  let JSONLoader = JSONLoaders()
  let PLYLoader = PLYLoaders()

  var body: some View {
    ZStack {
      Color.black.opacity(0.1).ignoresSafeArea()
        .onTapGesture { withAnimation { showPopup = false } }

      VStack(spacing: 16) {
        Text("Match Items")
          .font(.headline)
          .padding(.top)

        ScrollView {
          ForEach($plyMatches) { $match in
            PLYMatchRow(
              match: $match,
              jsonCandidates: jsonCandidates,
              onTapPreview: { selectedPLYForPreview = match }
            )
          }
        }

        Button("Confirm Matches") {
          for match in plyMatches {
            guard let json = match.matchedJSON else { continue }
            try? JSONLoader.injectJSONMetadataIntoBinaryPLY(
              plyURL: match.plyURL,
              jsonMetadata: json.dictionaryRepresentation,
              outputURL: match.plyURL
            )
            _ = JSONLoader.createItemFromMetadataJSON(
              jsonURL: json.url,
              plyFileName: match.plyURL.lastPathComponent,
              user: user,
              context: context
            )
          }

          withAnimation {
            showPopup = false
            onComplete()
          }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.teal)
        .foregroundColor(.white)
        .cornerRadius(10)
        .padding(.horizontal)

        Button("Cancel") {
          withAnimation {
            showPopup = false
          }
        }
        .foregroundColor(.red)
        .padding(.bottom)
      }
      .frame(maxWidth: 500)
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .shadow(radius: 10)

      .fullScreenCover(item: $selectedPLYForPreview) { match in
        NavigationView {
          VStack {
            if let node = match.previewNode {
              SceneView(
                scene: {
                  let scene = SCNScene()
                  scene.rootNode.addChildNode(node.clone())
                  return scene
                }(), options: [.allowsCameraControl])
            }
          }
          .navigationTitle(match.plyURL.lastPathComponent)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Close") {
                selectedPLYForPreview = nil
              }
            }
          }
        }
      }
    }.onAppear {
      PLYStateModel.buildPLYMatchesFromDownloads()
      JSONStateModel.buildJSONCandidatesFromDownloads()
    }
  }
}

struct JSONCandidate: Identifiable, Hashable {
  let id = UUID()
  let label: String
  let url: URL

  var dictionaryRepresentation: [String: Any] {
    do {
      let data = try Data(contentsOf: url)
      print("🔍 Trying to decode: \(url.lastPathComponent)")
      let raw = try JSONSerialization.jsonObject(with: data)

      if let array = raw as? [[String: Any]], let first = array.first {
        print("✅ Successfully loaded array from \(url.lastPathComponent)")
        return first
      } else if let dict = raw as? [String: Any] {
        print("⚠️ \(url.lastPathComponent) was a dict, not array — using anyway")
        return dict
      } else {
        print("⚠️ Invalid JSON format in \(url.lastPathComponent) — not dict or array")
      }
    } catch {
      print("❌ Failed to decode \(url.lastPathComponent): \(error.localizedDescription)")
    }
    return [:]
  }
}

struct PLYMatch: Identifiable {
  let id = UUID()
  let plyURL: URL
  var matchedJSON: JSONCandidate?
  var previewNode: SCNNode? = nil
}
