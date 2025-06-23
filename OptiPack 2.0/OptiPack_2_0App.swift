import SwiftData
import SwiftUI

@main
struct OptiPack_2_0App: App {
  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @AppStorage("isDarkMode") private var isDarkMode = false
  @StateObject private var authManager = AuthManager()

  var body: some Scene {
    WindowGroup {
      StartupView()
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .environmentObject(authManager)
    }
    .modelContainer(for: [
      UserCredentials.self,
      Item.self,
      ItemDetails.self,
      Inventory.self,
      InventoryCluster.self,
    ])
  }
}
