import SwiftUI

struct CustomButton: View {
  var title: String
  var icon: String
  var onClick: () -> Void

  var body: some View {
    Button(
      action: onClick,
      label: {
        HStack {
          Text(title)
          Image(systemName: icon)
        }
        .fontWeight(.bold)
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 35)
        .background(.teal, in: .capsule)
      })
  }
}
