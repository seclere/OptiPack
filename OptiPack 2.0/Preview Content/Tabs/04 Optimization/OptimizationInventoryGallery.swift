import SwiftData
import SwiftUI

struct OptimizationInventoryGalleryView: View {
  @Query var inventories: [Inventory]
  @Query var InventoryClusters: [InventoryCluster]
  @State private var selectedInventory: Inventory? = nil

  let selectedCategory: String
  let searchText: String
  let user: UserCredentials

  @State private var showOptimizeAlert = false

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
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(filteredInventories, id: \.id) { inventory in
          VStack {
            Rectangle()
              .fill(Color(hex: "EFF0F3"))
              .frame(width: 176, height: 120)
              .cornerRadius(10)

            Text(inventory.inventoryName)
              .font(.system(size: 15))
              .frame(width: 163, alignment: .leading)
              .foregroundColor(.white)

            Text(inventory.inventoryCategory.rawValue)
              .font(.system(size: 12))
              .frame(width: 163, alignment: .leading)
              .foregroundColor(.teal)
          }
          .onTapGesture {
            selectedInventory = inventory
            showOptimizeAlert = true
          }
        }
      }
    }
    .alert("Optimize Inventory?", isPresented: $showOptimizeAlert) {
      Button("Optimize", role: .none) {
        print("Optimize pressed.")
      }
      Button("Cancel", role: .cancel) {
        print("Cancel pressed.")
      }
    } message: {
      Text("Contents of selected inventory will be packed into the container.")
    }
  }
}
