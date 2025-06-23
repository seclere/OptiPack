// Team Differential || OptiPack 2.0 || ItemDetails.swift

// COMPREHENSIVE DESCRIPTION:
//

import Foundation
import SwiftData

enum fixedCategory: String, CaseIterable, Codable {
  case miscellaneous = "Miscellaneous"
  case electronics = "Electronics"
  case food = "Food"
  case fragile = "Fragile"

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)

    switch raw {
    case "Miscellaneous": self = .miscellaneous
    case "Electronics", "Electronic": self = .electronics
    case "Food": self = .food
    case "Fragile": self = .fragile
    case "miscellaneous": self = .miscellaneous
    case "electronics", "electronic": self = .electronics
    case "food": self = .food
    case "fragile": self = .fragile
    default:
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unknown category: \(raw)")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.rawValue)
  }
}

@Model
class InventoryCluster {
  var name: String

  // one-to-many inventories (inverse is Inventory.inventoryCluster)
  @Relationship(deleteRule: .cascade, inverse: \Inventory.inventoryCluster) var inventories:
    [Inventory] = []

  // one-to-one user (inverse is UserCredentials.inventoryCluster)
  @Relationship var user: UserCredentials?

  init(name: String, user: UserCredentials? = nil, inventories: [Inventory] = []) {
    self.name = name
    self.user = user
    self.inventories = inventories
  }
}

@Model
class Inventory {
  var inventoryName: String
  var inventoryCategory: fixedCategory

  // many-to-many items (inverse is Item.inventories)
  @Relationship(deleteRule: .nullify, inverse: \Item.inventories) var items: [Item] = []

  // one-to-many InventoryCluster (inverse is InventoryCluster.inventories)
  @Relationship var inventoryCluster: InventoryCluster?

  init(inventoryName: String, inventoryCategory: fixedCategory, items: [Item] = []) {
    self.inventoryName = inventoryName
    self.inventoryCategory = inventoryCategory
    self.items = items
  }
}

@Model
class Item {
  var label: String
  var plyFileName: String?

  // many-to-many inventories (inverse is Inventory.items)
  @Relationship(deleteRule: .nullify) var inventories: [Inventory] = []
  // one-to-many user (inverse is UserCredentials.items)
  @Relationship var user: UserCredentials

  @Relationship(deleteRule: .cascade) var details: ItemDetails?

  init(label: String, plyFileName: String? = nil, details: ItemDetails?, user: UserCredentials) {
    self.label = label
    self.plyFileName = plyFileName
    self.details = details
    self.user = user
  }
}

struct ItemData: Codable {
  let id: Int
  let type: String
  let category: String
  let stackable: Bool
  let fragile: Bool
}

@Model
class ItemDetails {
  var itemName: String
  var itemCategory: fixedCategory
  var width: Float
  var depth: Float
  var height: Float
  var weight: Float
  var allowedAngles: [Float]
  var stackable: Bool
  var fragile: Bool

  @Relationship var item: Item?

  init(
    itemName: String,
    itemCategory: fixedCategory,
    width: Float,
    depth: Float,
    height: Float,
    weight: Float,
    allowedAngles: [Float],
    stackable: Bool,
    fragile: Bool,
    item: Item? = nil
  ) {
    self.itemName = itemName
    self.itemCategory = itemCategory
    self.width = width
    self.depth = depth
    self.height = height
    self.weight = weight
    self.allowedAngles = allowedAngles
    self.stackable = stackable
    self.fragile = fragile
  }
}
