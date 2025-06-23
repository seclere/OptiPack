// Team Differential || OptiPack 2.0 || InventoryThumbnail.swift

// COMPREHENSIVE DESCRIPTION:
//

import Foundation
import SwiftData
import SwiftUI

struct InventoryThumbnail: View {
  @State private var showEditor = false

  @Bindable var inventory: Inventory
  let invThumbnailName: String
  let invThumbnailCategory: String

  var body: some View {
    VStack {
      Rectangle()
        .fill(Color(hex: "EFF0F3"))
        .frame(width: 176, height: 120)
        .cornerRadius(10)

      Text(invThumbnailName)
        .font(.system(size: 15))
        .frame(width: 163, alignment: .leading)

      Text(invThumbnailCategory)
        .font(.system(size: 12))
        .frame(width: 163, alignment: .leading)
        .foregroundColor(Color(hex: "8F9195"))
    }
    .onTapGesture {
      showEditor = true
    }
    .sheet(isPresented: $showEditor) {
      EditInventoryView(inventory: inventory)
    }
  }

}

/*
#Preview {
    InventoryThumbnail(inventory: inventory, invThumbnailName: "Example", invThumbnailCategory: "Miscellaneous")
}
*/
