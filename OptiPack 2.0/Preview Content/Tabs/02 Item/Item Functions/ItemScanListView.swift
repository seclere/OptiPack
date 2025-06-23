import SwiftData
import SwiftUI

struct ItemScanListView: View {
  @EnvironmentObject var authManager: AuthManager
  @State private var source: String = "ItemTab"

  let categ: String
  let sortAscending: Bool
  let searchText: String

  private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 15), count: 3)

  @Query private var allItems: [Item]

  private var filteredItems: [Item] {
    guard let currentUser = authManager.currentUser else { return [] }

    var result = allItems.filter { $0.user == currentUser }

    if categ != "All" {
      result = result.filter { $0.details?.itemCategory.rawValue == categ }
    }

    if !searchText.isEmpty {
      result = result.filter { $0.label.localizedStandardContains(searchText) }
    }

    return result.sorted {
      sortAscending
        ? $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        : $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedDescending
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 15) {
          ForEach(filteredItems, id: \.id) { item in
            ItemScanThumbnailView(item: item, source: $source)
          }
        }
      }
    }
  }
}
