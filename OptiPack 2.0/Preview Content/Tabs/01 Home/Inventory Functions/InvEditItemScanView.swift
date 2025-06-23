import SwiftData
import SwiftUI

struct InvEditItemScanView: View {
  @Bindable var scan: ItemDetails
  @State private var showConfirmationAlert = false
  @State private var isEditing = false
  @Environment(\.modelContext) private var modelContext

  @EnvironmentObject var authManager: AuthManager

  @Query private var allInventories: [Inventory]

  private var inventories: [Inventory] {
    guard let cluster = authManager.currentUser?.inventoryCluster else { return [] }
    return allInventories.filter { cluster.inventories.contains($0) }
  }

  @State private var showInventoryPicker = false
  @State private var selectedInventoryIndex: Int? = nil

  var body: some View {
    NavigationStack {
      ZStack {
        Form {
          Section(
            header: Text("Item Details")
              .font(.system(size: 15))
          ) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Item Name")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", text: $scan.itemName)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Category")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              Picker("", selection: $scan.itemCategory) {
                ForEach(fixedCategory.allCases, id: \.self) { category in
                  Text(category.rawValue).tag(category)
                }
              }
              .pickerStyle(.segmented)
              .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Width (cm)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.width, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Depth (cm)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.depth, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Height (cm)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.height, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text("Weight (kg)")
                .font(.system(size: 15))
                .foregroundColor(.gray)
              TextField("", value: $scan.weight, format: .number)
                .keyboardType(.decimalPad)
                .disabled(!isEditing)
            }

            Toggle("Stackable", isOn: $scan.stackable)
              .disabled(!isEditing)
              .tint(.teal)
            Toggle("Fragile", isOn: $scan.fragile)
              .disabled(!isEditing)
              .tint(.teal)
          }
        }
        .foregroundColor(isEditing ? .primary : .teal)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              withAnimation(.easeInOut(duration: 0.2)) {
                isEditing.toggle()
              }
              print("Edit mode: \(isEditing)")
            } label: {
              Image(systemName: isEditing ? "" : "pencil")
                .foregroundColor(isEditing ? .teal : .secondary)

              Text(isEditing ? "Done" : "Edit")
                .foregroundColor(isEditing ? .teal : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .font(.system(size: 17))
          }
        }

        if isEditing {
          HStack {
            Button(action: {
              showConfirmationAlert = true
            }) {
              HStack {
                Image(systemName: "trash.fill")
                  .foregroundColor(.red)
                Text("Remove from Inventory")
                  .foregroundColor(.red)
              }
              .padding()
              .padding([.leading, .trailing], 20)
            }
            .alert(isPresented: $showConfirmationAlert) {
              Alert(
                title: Text("Are you sure?"),
                message: Text(
                  "Do you really want to remove this item? This action cannot be undone."),
                primaryButton: .destructive(Text("Remove")) {
                  //removeItem()
                },
                secondaryButton: .cancel()
              )
            }

            Spacer()
          }
          .padding(.top, 340)
        }
      }
    }
  }

  /*
  private func removeItem() {
      if let item = scan.item {
          if let index = inventory.items.firstIndex(where: { $0 === item }) {
              if let inventory = currentInventory {
                  ForEach(inventory.items) { item in
                      inventory.items.remove(at: index)
                      try? modelContext.save()
                  }
              } else {
                  Text("No inventory selected.")
              }
          }
      }
  }
   */
}
