// Team Differential || OptiPack 2.0 || ViewExtensions.swift

// COMPREHENSIVE DESCRIPTION:
// Custom extensions for efficient UI creation.

import SwiftUI

extension Color {
  init(hex: String) {
    let scanner = Scanner(string: hex)
    if hex.hasPrefix("#") {
      scanner.currentIndex = hex.index(after: hex.startIndex)
    }

    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)

    let red = Double((rgb >> 16) & 0xFF) / 255.0
    let green = Double((rgb >> 8) & 0xFF) / 255.0
    let blue = Double(rgb & 0xFF) / 255.0

    self.init(red: red, green: green, blue: blue)
  }
}

extension View {

  @ViewBuilder
  func hSpacing(_ alignment: Alignment = .center) -> some View {
    self
      .frame(maxWidth: .infinity, alignment: alignment)
  }

  @ViewBuilder
  func vSpacing(_ alignment: Alignment = .center) -> some View {
    self
      .frame(maxHeight: .infinity, alignment: alignment)
  }

  @ViewBuilder
  func disableWithOpacity(_ condition: Bool) -> some View {
    self
      .disabled(condition)
      .opacity(condition ? 0.5 : 1)
  }
}
