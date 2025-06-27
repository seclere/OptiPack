import SwiftUI

struct HomeTab: View {
  @EnvironmentObject var authManager: AuthManager
  @EnvironmentObject var notificationManager: NotificationManager

  @State private var showCreateInventory = false
  @StateObject private var keyboardObserver = KeyboardObserver()
  @State private var searchInput = ""
  @State private var selectedCategory = "All"
  @State private var scanCount = 0

  var body: some View {
    NavigationView {
      VStack(spacing: 15) {
        // HEADER
        Text("Your Inventories")
          .font(.system(size: 24))
          .fontWeight(.bold)
          .frame(maxWidth: 380, alignment: .leading)

        // SEARCH BAR
        HStack {
          Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "8F9195"))
          TextField("Search", text: $searchInput).foregroundColor(.black)

          if !searchInput.isEmpty {
            Button(action: { searchInput = "" }) {
              Image(systemName: "xmark.circle.fill")
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "8F9195"))
            }
            .frame(maxWidth: 71, maxHeight: 35, alignment: .trailing)
          }
        }
        .frame(maxWidth: 360, maxHeight: 35)
        .padding(.horizontal, 12)
        .background(Color(hex: "EFF0F3"))
        .cornerRadius(6)

        // CATEGORY SCROLL
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 20) {
            let categories = ["All", "Electronics", "Food", "Fragile", "Miscellaneous"]
            ForEach(categories, id: \.self) { category in
              Button(action: {
                selectedCategory = category
              }) {
                Text(category)
                  .foregroundColor(selectedCategory == category ? .primary : .gray)
              }
            }
          }
          .font(.system(size: 14))
          .fontWeight(.semibold)
        }
        .frame(maxWidth: 380)

        // INVENTORIES HEADER
        HStack {
          Text("Inventories").font(.system(size: 16))
          Spacer()
          Button(action: {
            withAnimation {
              showCreateInventory = true
            }
          }) {
            Image(systemName: "plus").foregroundColor(.primary)
          }
        }
        .frame(maxWidth: 380)
        .fontWeight(.bold)

        // INVENTORY GRID VIEW
        if let user = authManager.currentUser {
          InventoryGalleryView(
            selectedCategory: selectedCategory,
            searchText: searchInput,
            user: user
          )
        } else {
          Text("Please sign in to view your inventories.")
            .foregroundColor(.gray)
        }

        Spacer()
      }
      .padding(20)
    }
    .fullScreenCover(isPresented: $showCreateInventory) {
      ZStack {
        Color.black
          .opacity(0.00001)
          .edgesIgnoringSafeArea(.all)
          .onTapGesture {
            showCreateInventory = false
          }

        VStack {
          Spacer()
          Rectangle().fill(Color(hex: "1E1E1E"))
            .frame(maxWidth: .infinity, maxHeight: 100)
            .zIndex(-1)
        }

        VStack {
          Spacer()
          CreateInventory(showingInHomeTab: $showCreateInventory)
            .padding(.bottom, keyboardObserver.keyboardHeight)
            .animation(.easeOut(duration: 0.3), value: keyboardObserver.keyboardHeight)
        }
        .presentationBackground(.clear)
        .ignoresSafeArea()
      }
    }
  }
}

#Preview {
  HomeTab()
    .environmentObject(AuthManager())  // Don't forget to inject this in your App
}
