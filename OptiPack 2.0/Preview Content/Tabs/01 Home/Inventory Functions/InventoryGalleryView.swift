import SwiftData
import SwiftUI

struct InventoryGalleryView: View {
  @Query var inventories: [Inventory]
  @Query var InventoryClusters: [InventoryCluster]
  let selectedCategory: String
  let searchText: String
  let user: UserCredentials

  private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 40), count: 2)

  var filteredInventories: [Inventory] {
    let userInventories =
      InventoryClusters
      .filter { $0.user?.username == user.username }
      .flatMap { $0.inventories }

    let filteredByCategory =
      selectedCategory == "All"
      ? userInventories
      : userInventories.filter { $0.inventoryCategory.rawValue == selectedCategory }

    let filteredBySearch =
      searchText.isEmpty
      ? filteredByCategory
      : filteredByCategory.filter {
        $0.inventoryName.localizedCaseInsensitiveContains(searchText)
      }

    return filteredBySearch
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      LazyVGrid(columns: columns, spacing: 20) {
        ForEach(filteredInventories, id: \.id) { inventory in
          InventoryThumbnail(
            inventory: inventory,
            invThumbnailName: inventory.inventoryName,
            invThumbnailCategory: inventory.inventoryCategory.rawValue
          )
        }
      }
      .padding(.horizontal, 20)
    }
  }
}
