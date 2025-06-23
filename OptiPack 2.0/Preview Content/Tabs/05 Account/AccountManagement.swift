import PhotosUI
import SwiftData
import SwiftUI

struct AccountManagement: View {
  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @Environment(\.modelContext) private var modelContext
  @Query private var allUsers: [UserCredentials]

  @State private var newUsername: String = ""
  @State private var newPassword: String = ""
  @State private var confirmPassword: String = ""
  @State private var isEditingUsername = false
  @State private var isEditingPassword = false
  @State private var profileImageSelection: PhotosPickerItem? = nil
  @State private var profileUIImage: UIImage? = nil

  private var currentUser: UserCredentials? {
    guard let id = loggedInUserID else { return nil }
    return allUsers.first(where: { $0.email == id })
  }

  var body: some View {
    Form {

      Section(header: Text("Account Details").font(.system(size: 15))) {
        VStack(alignment: .leading, spacing: 20) {
          // Username Section
          if let user = currentUser {
            if isEditingUsername {
              Text("Change Username")
                .font(.system(size: 17))

              TextField("Enter new username", text: $newUsername)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 17))

              Text("Current username: \(user.username)")
                .font(.subheadline)
                .foregroundColor(.gray)

              HStack {
                Button("Save Changes") {
                  user.username = newUsername
                  try? modelContext.save()
                  isEditingUsername = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newUsername.isEmpty)

                Button("Cancel") {
                  isEditingUsername = false
                }
                .buttonStyle(.bordered)
              }
            } else {
              Button {
                newUsername = user.username
                isEditingUsername = true
              } label: {
                Text("Change Username")
                  .font(.system(size: 17))
              }
            }
          } else {
            Text("No user found.")
          }
        }

        VStack(alignment: .leading, spacing: 20) {
          // Change Profile Picture Section
          if let user = currentUser {
            PhotosPicker(
              selection: $profileImageSelection,
              matching: .images,
              photoLibrary: .shared()
            ) {
              Text("Change Profile Picture")
                .font(.system(size: 17))
            }
            .onChange(of: profileImageSelection) { newItem in
              Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                  let user = currentUser
                {
                  user.profileImageData = data
                  try? modelContext.save()
                }
              }
            }
          }
        }
      }

      // Password Section
      Section(header: Text("Security").font(.system(size: 15))) {
        VStack(alignment: .leading, spacing: 20) {
          if let user = currentUser {
            if isEditingPassword {
              Text("Change Password")
                .font(.system(size: 17))

              SecureField("Enter new password", text: $newPassword)
                .textFieldStyle(.roundedBorder)

              SecureField("Confirm new password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

              HStack {
                Button("Save Changes") {
                  user.password = newPassword
                  try? modelContext.save()
                  isEditingPassword = false
                  newPassword = ""
                  confirmPassword = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPassword.isEmpty || newPassword != confirmPassword)

                Button("Cancel") {
                  isEditingPassword = false
                  newPassword = ""
                  confirmPassword = ""
                }
                .buttonStyle(.bordered)
              }

              if !newPassword.isEmpty && newPassword != confirmPassword {
                Text("Passwords do not match.")
                  .font(.footnote)
                  .foregroundColor(.red)
              }
            } else {
              Button {
                isEditingPassword = true
              } label: {
                Text("Change Password")
                  .font(.system(size: 17))
              }
            }
          }
        }
      }

    }
    .navigationTitle("Account Management")
    .tint(.teal)
  }
}

#Preview {
  AccountManagement()
}
