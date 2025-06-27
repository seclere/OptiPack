//
//  NotificationTypes.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 6/27/25.
//

import SwiftUICore

enum NotificationType {
  case success
  case error
  case info

  var color: Color {
    switch self {
    case .success: return Color.green
    case .error: return Color.red
    case .info: return Color.blue
    }
  }

  var icon: String {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error: return "xmark.octagon.fill"
    case .info: return "info.circle.fill"
    }
  }
}

struct AppNotification {
  let message: String
  let type: NotificationType
  let onTap: (() -> Void)?

  init(message: String, type: NotificationType, onTap: (() -> Void)? = nil) {
    self.message = message
    self.type = type
    self.onTap = onTap
  }
}

class NotificationManager: ObservableObject {
  static let shared = NotificationManager()
  @Published var currentNotification: AppNotification? = nil
  @Published var isVisible: Bool = false

  func show(_ notification: AppNotification, duration: Double = 3.0) {
    currentNotification = notification
    isVisible = true

    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      self.isVisible = false
    }
  }
}
