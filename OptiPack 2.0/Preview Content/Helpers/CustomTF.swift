import SwiftUI

struct CustomTF: View {
  var sfIcon: String
  var iconTint: Color = .gray
  var hint: String
  var isPassword: Bool = false
  @Binding var value: String
  @State var showPassword: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: sfIcon)
        .foregroundStyle(iconTint)
        .frame(width: 30)
      VStack(alignment: .leading, spacing: 8) {
        if isPassword {
          Group {
            if showPassword {
              TextField(hint, text: $value)
            } else {
              SecureField(hint, text: $value)
            }
          }
        } else {
          TextField(hint, text: $value)
        }

        Divider()
      }
      .overlay(alignment: .trailing) {
        if isPassword {
          Button(
            action: {
              showPassword.toggle()
            },
            label: {
              Image(systemName: showPassword ? "eye.slash" : "eye")
                .foregroundStyle(.gray)
                .padding(20)
                .contentShape(Rectangle())
            })
        }
      }
    }

  }
}
