import SwiftData
import SwiftUI

struct CreateInventory: View {
  @Binding var showingInHomeTab: Bool
  @State private var name = ""
  @State private var categ = "Electronics"
  @State private var categories = ["Electronics", "Food", "Fragile", "Miscellaneous"]

  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var authManager: AuthManager

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button(action: {
          withAnimation {
            showingInHomeTab = false
          }
        }) {
          Image(systemName: "xmark")
            .fontWeight(.bold)
            .foregroundColor(.white)
        }
        .frame(maxWidth: 71, maxHeight: 35, alignment: .leading)

        Text("New Inventory")
          .frame(maxWidth: 120, maxHeight: 9.64, alignment: .center)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(29)

        Button("Create", action: createInventory)
          .frame(maxWidth: 71, maxHeight: 35)
          .fontWeight(.medium)
          .foregroundColor(.black)
          .background(Color(hex: "EFF0F3"))
          .cornerRadius(20)
      }

      Text("Inventory Name")
        .frame(maxWidth: 350, maxHeight: 35, alignment: .leading)
        .fontWeight(.semibold)
        .foregroundColor(.white)

      HStack {
        TextField("Name", text: $name)
          .frame(maxWidth: 190, maxHeight: 35, alignment: .leading)
          .padding(.leading, 10)
          .foregroundColor(.black)
          .background(.white)
          .cornerRadius(6)

        Picker("Categories", selection: $categ) {
          ForEach(categories, id: \.self) { category in
            Text(category)
          }
        }
        .frame(maxWidth: 150, maxHeight: 35, alignment: .center)
        .background(.white)
        .cornerRadius(6)
      }

    }
    .frame(maxWidth: .infinity, maxHeight: 200, alignment: .top)
    .background(Color(hex: "1E1E1E"))
    .cornerRadius(40)
  }

  private func createInventory() {
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
      print("Inventory name is empty.")
      return
    }

    guard let category = fixedCategory(rawValue: categ) else {
      print("Invalid category.")
      return
    }

    guard let user = authManager.currentUser else {
      print("No logged in user.")
      return
    }

    let newInventory = Inventory(inventoryName: name, inventoryCategory: category)

    if let cluster = user.inventoryCluster {
      cluster.inventories.append(newInventory)
    } else {
      let newCluster = InventoryCluster(
        name: "\(user.username)'s Cluster", inventories: [newInventory])
      user.inventoryCluster = newCluster
      modelContext.insert(newCluster)
    }

    modelContext.insert(newInventory)
    try? modelContext.save()

    print("Created inventory: \(newInventory.inventoryName) under \(category.rawValue)")
    showingInHomeTab = false
    name = ""
  }
}
