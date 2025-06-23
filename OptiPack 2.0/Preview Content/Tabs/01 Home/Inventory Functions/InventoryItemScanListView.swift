import SwiftData
import SwiftUI

struct InventoryItemScanListView: View {
  @Binding var inventory: Inventory
  @Binding var currentInventory: Inventory
  let categ: String
  let sortAscending: Bool

  @Environment(\.modelContext) private var modelContext

  @State private var showRemoveAlert = false
  @State private var scanToRemove: ItemDetails? = nil

  private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 7), count: 3)

  var filteredScans: [ItemDetails] {

    let filteredByCategory =
      categ == "All"
      ? inventory.items.compactMap { $0.details }
      : inventory.items.filter { $0.details?.itemCategory.rawValue == categ }
        .compactMap { $0.details }

    return filteredByCategory.sorted {
      sortAscending
        ? $0.itemName.localizedCaseInsensitiveCompare($1.itemName) == .orderedAscending
        : $0.itemName.localizedCaseInsensitiveCompare($1.itemName) == .orderedDescending
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 5) {
          ForEach(filteredScans, id: \.id) { scan in
            ZStack(alignment: .bottomTrailing) {
              Color(hex: "EFF0F3")

              VStack(alignment: .trailing, spacing: 2) {
                Spacer()
                VStack(alignment: .trailing, spacing: -1) {
                  Text(scan.itemName)
                    .font(.system(size: 13))
                    .foregroundColor(.black)
                  Text(scan.itemCategory.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                }
                .padding(10)
              }
            }
            .frame(width: 115, height: 150)
            .cornerRadius(10)
            .onTapGesture {
              scanToRemove = scan
              showRemoveAlert = true
            }
          }
        }
      }
      .alert("Remove Item?", isPresented: $showRemoveAlert, presenting: scanToRemove) { scan in
        Button("Remove", role: .destructive) {
          removeScan(scan)
        }
        Button("Cancel", role: .cancel) {}
      } message: { scan in
        Text("Do you want to remove '\(scan.itemName)' from the inventory?")
      }
    }
  }

  private func removeScan(_ scan: ItemDetails) {
    // Find the Item that has these details
    if let itemToRemove = inventory.items.first(where: { $0.details?.id == scan.id }) {
      if let index = inventory.items.firstIndex(where: { $0.id == itemToRemove.id }) {
        inventory.items.remove(at: index)
        do {
          try modelContext.save()
        } catch {
          print("Failed to remove item from inventory: \(error)")
        }
      }
    }
  }
}
