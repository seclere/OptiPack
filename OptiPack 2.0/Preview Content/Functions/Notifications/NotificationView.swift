//
//  NotificationView.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/27/25.
//

import SwiftUICore

struct NotificationBanner: View {
  @EnvironmentObject var notificationManager: NotificationManager

  var body: some View {
    if let notification = notificationManager.currentNotification, notificationManager.isVisible {
      HStack {
        Image(systemName: notification.type.icon)
          .foregroundColor(.white)
        Text(notification.message)
          .foregroundColor(.white)
          .fontWeight(.medium)
        Spacer()
      }
      .padding()
      .background(notification.type.color)
      .cornerRadius(12)
      .padding(.horizontal)
      .onTapGesture {
        notification.onTap?()
        notificationManager.isVisible = false
      }
      .transition(.move(edge: .top).combined(with: .opacity))
      .animation(.spring(), value: notificationManager.isVisible)
    }
  }
}
