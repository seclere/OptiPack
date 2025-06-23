import SwiftData
import SwiftUI

@Model
class UserCredentials {
  @Attribute var email: String
  @Attribute var username: String
  @Attribute var password: String
  var profileImageData: Data?

  @Relationship(deleteRule: .cascade, inverse: \InventoryCluster.user) var inventoryCluster:
    InventoryCluster?
  @Relationship(deleteRule: .cascade, inverse: \Item.user) var items: [Item] = []

  init(
    username: String, password: String, email: String, profileImageData: Data? = nil,
    inventoryCluster: InventoryCluster? = nil, items: [Item] = []
  ) {
    self.email = email
    self.username = username
    self.password = password
    self.profileImageData = profileImageData
    self.inventoryCluster = inventoryCluster
    self.items = items
  }
}
