// Team Differential || OptiPack 2.0 || ScanTab.swift

// COMPREHENSIVE DESCRIPTION:

import Metal
import SwiftUI

struct ARViewContainer: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> ViewController {
    return ViewController()
  }

  func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}

struct ScanTab: View {
  @EnvironmentObject var notificationManager: NotificationManager
  var body: some View {
    ARViewContainer()
      .edgesIgnoringSafeArea(.all)

  }
}

#Preview {
  ScanTab()
}
