// Team Differential || OptiPack 2.0 || ContentView.swift

// COMPREHENSIVE DESCRIPTION:
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @AppStorage("selectedTab") private var selectedTab: String = "home"
  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @AppStorage("isDarkMode") private var isDarkMode: Bool = false
  @StateObject var notificationManager = NotificationManager()

  @EnvironmentObject var authManager: AuthManager

  var body: some View {
    if loggedInUserID != nil {
      ZStack(alignment: .top) {
        TabView(selection: $selectedTab) {
          HomeTab()
            .tabItem {
              Label("Home", systemImage: "house")
            }
            .tag("home")

          ItemTab()
            .tabItem {
              Label("Items", systemImage: "cone")
            }
            .tag("items")

          ScanTab()
            .tabItem {
              Label("Scan", systemImage: "camera")
            }
            .tag("scan")

          OptimizationTab()
            .tabItem {
              Label("Optimize", systemImage: "shippingbox")
            }
            .tag("optimize")

          AccountTab()
            .tabItem {
              Label("Account", systemImage: "person.circle")
            }
            .tag("account")
        }
        .onAppear {
          let appearance = UITabBarAppearance()
          appearance.configureWithOpaqueBackground()
          appearance.backgroundColor = .white
          UITabBar.appearance().standardAppearance = appearance
          UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        VStack {
          if notificationManager.isVisible {
            NotificationBanner()
          }
          Spacer()
        }
        .padding(.top, 50)
        .transition(.move(edge: .top).combined(with: .opacity))
      }
      .environmentObject(notificationManager)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea(.keyboard, edges: .bottom)
      .toolbarBackground(.visible, for: .tabBar)
      .toolbar(.hidden, for: .navigationBar)
      .accentColor(.teal)
    } else {
      Text("Logged out")
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(AuthManager())
}
