// Team Differential || OptiPack 2.0 || ContentView.swift

// COMPREHENSIVE DESCRIPTION:
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @AppStorage("isDarkMode") private var isDarkMode: Bool = false

  @EnvironmentObject var authManager: AuthManager

  var body: some View {
    if loggedInUserID != nil {
      TabView {
        HomeTab()
          .tabItem {
            Label("Home", systemImage: "house")
          }

        ItemTab()
          .tabItem {
            Label("Items", systemImage: "cone")
          }

        ScanTab()
          .tabItem {
            Label("Scan", systemImage: "camera")
          }

        OptimizationTab()
          .tabItem {
            Label("Optimize", systemImage: "shippingbox")
          }

        AccountTab()
          .tabItem {
            Label("Account", systemImage: "person.circle")
          }
      }
      .onAppear {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea(.keyboard, edges: .bottom)
      .toolbarBackground(.visible, for: .tabBar)
      .toolbar(.hidden, for: .navigationBar)
      .accentColor(.teal)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea(.keyboard, edges: .bottom)
    } else {
      Text("Logged out")
    }

  }
}

#Preview {
  ContentView()
    .environmentObject(AuthManager())
}
