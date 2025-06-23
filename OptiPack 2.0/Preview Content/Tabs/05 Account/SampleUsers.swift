import Foundation
import SwiftData
import SwiftUI

func createSampleUsers(modelContext: ModelContext) {
  let sampleUsers:
    [(String, String, String, [(String, Float, Float, Float, Float, [Float], Bool, Bool, String?)])] =
      [
        (
          "alice", "123", "alice@example.com",
          [
            ("Box A", 10, 20, 5, 2.5, [0], true, false, "THE-FOX.ply")
          ]
        ),
        (
          "bob", "123", "bob@example.com",
          [
            ("Crate B", 15, 15, 15, 4.0, [0, 90], false, true, "THE-FOX.ply")
          ]
        ),
        (
          "carol", "123", "carol@example.com",
          [
            ("Pallet C", 50, 40, 10, 10.0, [0, 180], true, false, "THE-FOX.ply"),
            ("Small Box A", 5, 5, 5, 0.5, [0], true, true, "THE-FOX.ply"),
            ("Small Box B", 5, 5, 5, 0.5, [0], true, true, "THE-FOX.ply"),
            ("Small Box C", 5, 5, 5, 0.5, [0], true, true, "THE-FOX.ply"),
            ("Small Box D", 5, 5, 5, 0.5, [0], true, true, "THE-FOX.ply"),
          ]
        ),
        ("dave", "123", "dave@example.com", []),
        (
          "eve", "123", "eve@example.com",
          [
            ("Monitor", 30, 20, 5, 3.2, [0], false, true, "THE-FOX.ply")
          ]
        ),
        (
          "frank", "123", "frank@example.com",
          [
            ("Toolbox", 25, 25, 10, 8.5, [0, 90], true, false, "THE-FOX.ply")
          ]
        ),
        (
          "grace", "123", "grace@example.com",
          [
            ("Vase", 8, 8, 20, 1.0, [0], false, true, "THE-FOX.ply")
          ]
        ),
        (
          "heidi", "123", "heidi@example.com",
          [
            ("Books", 20, 30, 5, 5.0, [0, 90, 180], true, false, "THE-FOX.ply")
          ]
        ),
        (
          "ivan", "123", "ivan@example.com",
          [
            ("Speaker", 10, 10, 25, 3.3, [0, 90], false, false, "THE-FOX.ply")
          ]
        ),
        (
          "judy", "123", "judy@example.com",
          [
            ("Lamp", 10, 10, 30, 2.7, [0], false, true, "THE-FOX.ply")
          ]
        ),
      ]

  for (username, password, email, itemsData) in sampleUsers {
    let cluster = InventoryCluster(name: "\(username)'s Cluster")
    let user = UserCredentials(
      username: username, password: password, email: email, inventoryCluster: cluster)
    let inventory = Inventory(
      inventoryName: "\(username)'s Inventory", inventoryCategory: .miscellaneous)

    for (name, width, depth, height, weight, angles, stackable, fragile, plyFileName) in itemsData {
      let details = ItemDetails(
        itemName: name,
        itemCategory: .miscellaneous,
        width: width,
        depth: depth,
        height: height,
        weight: weight,
        allowedAngles: angles,
        stackable: stackable,
        fragile: fragile
      )
      let item = Item(label: name, plyFileName: plyFileName, details: details, user: user)
      inventory.items.append(item)
    }

    cluster.inventories.append(inventory)
    modelContext.insert(user)

    print("Inserted user: \(username) with \(itemsData.count) items")
  }

  do {
    try modelContext.save()
    print("Model context saved successfully.")
  } catch {
    print("❌ Failed to save model context: \(error)")
  }
}
