import SwiftData
import SwiftUI

struct EditInventoryView: View {
  @State var inventory: Inventory
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var authManager: AuthManager

  @State private var isEditing = false
  @State private var showConfirmationAlert = false

  private var isOwner: Bool {
    guard let currentUser = authManager.currentUser,
      let cluster = currentUser.inventoryCluster
    else {
      return false
    }
    return cluster.inventories.contains(inventory)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Form {
          Section(
            header: Text("Inventory Details")
              .font(.system(size: 15))
          ) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Inventory Name")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("Inventory Name", text: $inventory.inventoryName).disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Inventory Category")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              Picker("Category", selection: $inventory.inventoryCategory) {
                ForEach(fixedCategory.allCases, id: \.self) { category in
                  Text(category.rawValue).tag(category)
                }
              }
              .pickerStyle(.segmented)
              .padding(.bottom, 10)
              .disabled(!isEditing)
            }
          }

          Section(
            header: Text("Items in Inventory")
              .font(.system(size: 15))
          ) {
            if inventory.items.isEmpty {
              Text("No items in inventory.")
                .foregroundColor(.gray)
            } else {
              InventoryItemScanListView(
                inventory: $inventory,
                currentInventory: $inventory,
                categ: "All",
                sortAscending: true
              )
              .padding(.top, 20)
            }
          }
        }
        .foregroundColor(isEditing ? .primary : .teal)
        .toolbar {
          if isOwner {
            ToolbarItem(placement: .navigationBarTrailing) {
              Button {
                isEditing.toggle()
              } label: {
                Image(systemName: isEditing ? "" : "pencil")
                Text(isEditing ? "Done" : "Edit")
              }
              .foregroundColor(isEditing ? .teal : .secondary)
            }
          }
        }

        if isEditing && isOwner {
          VStack {
            HStack {
              Spacer()
              Button(action: {
                showConfirmationAlert = true
              }) {
                HStack {
                  Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                  Text("Delete Inventory")
                    .foregroundColor(.red)
                }
                .padding()
                .padding([.leading, .trailing], 20)
              }
              .alert(isPresented: $showConfirmationAlert) {
                Alert(
                  title: Text("Are you sure?"),
                  message: Text(
                    "Do you really want to delete this inventory? This action cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) {
                    deleteInventory()
                  },
                  secondaryButton: .cancel()
                )
              }
            }
            Spacer()
          }
        }
      }
    }
    .onAppear {
      if !isOwner {
        print("Unauthorized access — dismissing")
        dismiss()
      }
    }
  }

  private func deleteInventory() {
    print("delete confirmed")
    modelContext.delete(inventory)
    do {
      try modelContext.save()
      print("Inventory successfully deleted.")
    } catch {
      print("Failed to delete inventory.")
    }
    dismiss()
  }
}
