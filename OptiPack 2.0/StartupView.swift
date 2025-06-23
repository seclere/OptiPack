// Team Differential || OptiPack 2.0 || StartupView.swift

// COMPREHENSIVE DESCRIPTION:
// The very entrance to Optipack.
// This is where the login verification/status will be set.

import SwiftUI

struct StartupView: View {
  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @State private var showSignup: Bool = false
  @Environment(\.modelContext) private var modelContext
  @AppStorage("hasSeededUsers") private var hasSeededUsers = false

  var body: some View {
    NavigationStack {

      if loggedInUserID != nil {
        ContentView()
      } else {
        LoginView(showSignup: $showSignup)
          .onAppear {
            if !hasSeededUsers {
              createSampleUsers(modelContext: modelContext)
              hasSeededUsers = true
            }
          }
          .navigationDestination(isPresented: $showSignup) {
            SignupView(showSignup: $showSignup)
          }
      }
    }
  }
}

#Preview {
  StartupView()
}
