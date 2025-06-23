// Team Differential || OptiPack 2.0 || Login.swift

// COMPREHENSIVE DESCRIPTION:
//

import SwiftData
import SwiftUI

struct LoginView: View {
  @EnvironmentObject var authManager: AuthManager
  @Binding var showSignup: Bool
  @State private var showContent = false
  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @State private var loggedInUser: UserCredentials?

  @State private var email: String = ""
  @State private var password: String = ""
  @State private var errorMessage: String?

  @Environment(\.modelContext) private var context
  @Query private var users: [UserCredentials]

  func loginUser(email: String, password: String, modelContext: ModelContext) -> UserCredentials? {
    let fetch = FetchDescriptor<UserCredentials>(
      predicate: #Predicate { $0.email == email && $0.password == password }
    )
    return try? modelContext.fetch(fetch).first
  }

  var body: some View {
    NavigationStack {
      if showContent {
        ContentView()
      } else {
        VStack(alignment: .leading, spacing: 15) {
          Spacer(minLength: 0)

          Text("Login")
            .font(.largeTitle)
            .fontWeight(.heavy)

          Text("Please sign in to continue")
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.gray)
            .padding(.top, -5)

          VStack(spacing: 25) {
            CustomTF(sfIcon: "at", hint: "Email address", value: $email)

            CustomTF(sfIcon: "lock", hint: "Password", isPassword: true, value: $password)
              .padding(.top, 5)

            if let errorMessage = errorMessage {
              Text(errorMessage)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(.red)
                .font(.caption)
                .padding(.top, -10)
            }

            CustomButton(title: "Login", icon: "arrow.right") {
              if !email.isEmpty && !password.isEmpty {
                authManager.signIn(email: email, password: password, modelContext: context)
                if let user = authManager.currentUser {
                  loggedInUser = user
                  loggedInUserID = user.email
                  showContent = true
                  errorMessage = nil
                } else {
                  errorMessage = "Invalid User Credentials."
                }

              }
            }
            .hSpacing(.trailing)
            .disableWithOpacity(email.isEmpty || password.isEmpty)

          }
          .padding(.top, 20)

          Spacer(minLength: 0)

          HStack(spacing: 6) {
            Group {
              Text("Don't have an account?")

              Button("Sign up") {
                showSignup.toggle()
              }
              .foregroundStyle(.teal)
            }
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.gray)
            .padding(.top, -5)
          }
        }
      }
    }
    .padding(.vertical, 15)
    .padding(.horizontal, 25)
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(isPresented: $showContent) {
      ContentView()
    }
  }
}

#Preview {
  StartupView()
}
