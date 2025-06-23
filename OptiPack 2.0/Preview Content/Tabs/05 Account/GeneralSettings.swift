import SwiftUI

struct GeneralSettings: View {
  @AppStorage("isDarkMode") private var isDarkMode: Bool = false
  @AppStorage("serverURL") private var serverURL: String =
    "https://1048-175-176-27-8.ngrok-free.app"
  @AppStorage("detectionPath") private var detectionPath: String = "/detect"
  @AppStorage("meshingPath") private var meshingPath: String = "/meshing"
  @AppStorage("productionPath") private var productionPath: String = "/production"
  @AppStorage("imageDetectionURL") private var imageDetectionURL: String =
    "https://1048-175-176-27-8.ngrok-free.app"

  var body: some View {
    Form {
      // Theme
      Section(header: Text("Theme").font(.system(size: 15))) {
        VStack {
          Toggle(isOn: $isDarkMode) {
            Label(
              isDarkMode ? "Dark Mode" : "Light Mode",
              systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
          }
          .padding()
          .toggleStyle(SwitchToggleStyle(tint: .teal))
        }
      }

      // Server Configuration
      Section(header: Text("Server Configuration").font(.system(size: 15))) {
        VStack(alignment: .leading, spacing: 10) {
          TextField("Base Server URL", text: $serverURL)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)

          TextField("Meshing Path", text: $meshingPath)
            .autocapitalization(.none)

        }
        .padding(.vertical, 5)
      }

      // Image Detection URL
      Section(header: Text("Image Detection").font(.system(size: 15))) {
        VStack(alignment: .leading, spacing: 10) {
          TextField("Image Detection URL", text: $imageDetectionURL)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)

          TextField("Detection Path", text: $detectionPath)
            .autocapitalization(.none)
        }
        .padding(.vertical, 5)
      }
    }
    .navigationBarTitle("General Settings")
  }
}

#Preview {
  NavigationView {
    GeneralSettings()
  }
}
