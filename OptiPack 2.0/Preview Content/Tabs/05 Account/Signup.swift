// Team Differential || OptiPack 2.0 || Signup.swift

// COMPREHENSIVE DESCRIPTION:
//

import SwiftData
import SwiftUI

struct SignupView: View {
  @Binding var showSignup: Bool
  @State private var showContent = false

  @State private var email: String = ""
  @State private var username: String = ""
  @State private var password: String = ""
  @State private var errorMessage: String?

  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @Environment(\.modelContext) private var context
  @Query private var users: [UserCredentials]
  @EnvironmentObject var authManager: AuthManager

  func signUp() {
    let fetch = FetchDescriptor<UserCredentials>(
      predicate: #Predicate { $0.email == email }
    )

    if let existing = try? context.fetch(fetch), !existing.isEmpty {
      errorMessage = "A user with that email already exists"
      return
    }

    let user = UserCredentials(
      username: username, password: password, email: email, inventoryCluster: nil)
    context.insert(user)
    authManager.currentUser = user
    loggedInUserID = user.email
    print("User created: \(user.username), email: \(user.email)")

    email = ""
    username = ""
    password = ""
    showSignup = false
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 15) {
        Button(
          action: {
            showSignup = false
          },
          label: {
            Image(systemName: "arrow.left")
              .font(.title2)
              .foregroundStyle(.gray)

          }
        )
        .padding(.top, 10)

        Text("Sign Up")
          .font(.largeTitle)
          .fontWeight(.heavy)
          .padding(.top, 25)

        Text("Please sign up to continue")
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(.gray)
          .padding(.top, -5)

        VStack(spacing: 25) {

          VStack(alignment: .leading, spacing: 4) {
            CustomTF(sfIcon: "at", hint: "Email address", value: $email)

            if let error = errorMessage {
              Text(error)
                .foregroundColor(.red)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          }

          CustomTF(sfIcon: "person", hint: "Username", value: $username)
            .padding(.top, 5)

          CustomTF(sfIcon: "lock", hint: "Password", isPassword: true, value: $password)
            .padding(.top, 5)

          CustomButton(title: "Continue", icon: "arrow.right") {
            if !email.isEmpty && !password.isEmpty {
              //showContent = true
              signUp()
            }
          }
          .hSpacing(.trailing)
          .disableWithOpacity(email.isEmpty || password.isEmpty || username.isEmpty)
        }
        .padding(.top, 20)

        Spacer(minLength: 0)

        HStack(spacing: 6) {
          Group {
            Text("Already have an account?")

            Button("Sign in") {
              showSignup = false
            }
            .foregroundStyle(.teal)
          }
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(.gray)
          .padding(.top, -5)

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
}

#Preview {
  SignupView(showSignup: .constant(true))
    .environmentObject(AuthManager())
}
