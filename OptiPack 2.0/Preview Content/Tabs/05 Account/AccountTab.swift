// Team Differential || OptiPack 2.0 || AccountTab.swift

// COMPREHENSIVE DESCRIPTION:
//

import SwiftData
import SwiftUI

struct AccountTab: View {

  @EnvironmentObject var notificationManager: NotificationManager

  @AppStorage("loggedInUserID") private var loggedInUserID: String?
  @State private var showLogoutConfirmation = false
  @State private var showDeleteConfirmation = false
  @Environment(\.modelContext) private var context

  @Query private var allUsers: [UserCredentials]

  private var currentUser: UserCredentials? {
    guard let id = loggedInUserID else { return nil }
    return allUsers.first(where: { $0.email == id })
  }

  func deleteAccount() {
    guard let user = currentUser else {
      print("No user found for deletion.")
      return
    }
    print("Deleting user: \(user.username)")

    context.delete(user)

    do {
      try context.save()
      loggedInUserID = nil
      print("User deleted successfully")
    } catch {
      print("Error deleting account: \(error.localizedDescription)")
    }
  }

  var body: some View {

    NavigationView {
      VStack {
        HStack(spacing: 225) {
          Text("Account")
            .font(.system(size: 24, weight: .bold))

          Button(action: {
            showLogoutConfirmation = true
            print("Log out button pressed.")
          }) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
              .foregroundColor(.primary).font(.system(size: 20, weight: .semibold))
          }
          .alert("Confirm Log Out", isPresented: $showLogoutConfirmation) {
            Button("Log Out", role: .destructive) {
              loggedInUserID = nil
            }
            Button("Cancel", role: .cancel) {}
          } message: {
            Text("Are you sure you want to log out?")
          }
        }
        .padding(.horizontal)

        // PROFILE
        VStack(spacing: 8) {
          if let data = currentUser?.profileImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 109, height: 109)
              .clipShape(Circle())
              .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
              .shadow(radius: 4)
          } else {
            Image(systemName: "person.crop.circle.fill")
              .resizable()
              .scaledToFit()
              .frame(width: 109, height: 109)
              .foregroundColor(.gray.opacity(0.6))
          }

          Text(currentUser?.username ?? "Guest")
            .font(.system(size: 20, weight: .semibold))
          Text(currentUser?.email ?? "guest@example.com")
            .font(.system(size: 16))
            .foregroundColor(.gray)
        }
        .padding(.top, 20)

        // BUTTONS (RAISED ABOVE TAB BAR)
        VStack {
          ZStack {

            VStack {
              Spacer()
              Rectangle()
                .foregroundColor(Color(hex: "EFF0F3"))
                .frame(maxWidth: .infinity, maxHeight: 200)
            }

            Rectangle()
              .foregroundColor(Color(hex: "EFF0F3"))
              .cornerRadius(30)
              .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
              VStack(spacing: 15) {
                accountButton(
                  title: "Account Management", icon: "person.fill", destination: AccountManagement()
                )
                accountButton(
                  title: "General Settings", icon: "gearshape", destination: GeneralSettings())
                Button(role: .destructive) {
                  showDeleteConfirmation = true
                } label: {
                  HStack {
                    ZStack {
                      Rectangle()
                        .cornerRadius(10)
                        .foregroundColor(Color.red.opacity(0.2))
                        .frame(width: 39, height: 39)
                        .padding(.leading, 12)
                        .padding(.trailing, 12)

                      Image(systemName: "trash")
                        .foregroundColor(.red)
                    }

                    Text("Delete Account")
                      .foregroundColor(.red)
                      .fontWeight(.medium)

                    Spacer()
                    Image(systemName: "chevron.right")
                      .foregroundColor(.red)
                      .fontWeight(.bold)
                      .padding(.trailing, 15)
                  }
                  .frame(maxWidth: 400, alignment: .leading)
                  .frame(height: 60)
                  .background(Color.white)
                  .cornerRadius(17)
                }
                .padding(.horizontal, 20)
              }
              .padding(.top, 30)
              .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                  deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
              } message: {
                Text("This action cannot be undone. Are you sure you want to delete your account?")
              }

            }
          }
        }
        .padding(.top, 30)
      }
    }.padding(.top, 20)
  }
}

func accountButton(title: String, icon: String, destination: some View, isDestructive: Bool = false)
  -> some View
{
  NavigationLink(destination: destination) {
    HStack {
      ZStack {
        Rectangle()
          .cornerRadius(10)
          .foregroundColor(isDestructive ? Color.red.opacity(0.2) : Color.gray.opacity(0.3))
          .frame(maxWidth: 39, maxHeight: 39)
          .padding(.leading, 12)
          .padding(.trailing, 12)

        Image(systemName: icon)
          .foregroundColor(isDestructive ? .red : .black)
      }

      Text(title)
        .foregroundColor(isDestructive ? .red : .black)
        .fontWeight(.medium)

      Spacer()
      Image(systemName: "chevron.right")
        .foregroundColor(isDestructive ? .red : .black)
        .fontWeight(.bold)
        .padding(.trailing, 15)
    }
    .frame(maxWidth: 400, alignment: .leading)
    .frame(height: 60)
    .background(Color.white)
    .cornerRadius(17)
  }
  .padding(.horizontal, 20)
}

#Preview {
  AccountTab()
}
