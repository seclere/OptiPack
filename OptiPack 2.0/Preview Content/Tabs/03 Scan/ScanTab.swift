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
  var body: some View {
    ARViewContainer()
      .edgesIgnoringSafeArea(.all)

    /*VStack(spacing: 20){
     Image(systemName: "exclamationmark.triangle")
     .resizable()
     .frame(width: 100, height: 100)
     Text("Scan tab under development!")
     .font(.system(size: 20))
     .fontWeight(.semibold)
     }
    
     }
     }*/
  }
}

#Preview {
  ScanTab()
}
