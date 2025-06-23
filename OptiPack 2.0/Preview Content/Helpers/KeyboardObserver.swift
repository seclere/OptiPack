// Team Differential || OptiPack 2.0 || KeyboardObserver.swift

// COMPREHENSIVE DESCRIPTION:
// KeyboardObserver is an ObservableObject that tracks the keyboard’s height in real-time.
// It updates the `keyboardHeight` property when the keyboard appears or disappears,
// allowing SwiftUI views to adjust their layout dynamically and avoid being obscured.

import SwiftUI

class KeyboardObserver: ObservableObject {
  @Published var keyboardHeight: CGFloat = 0

  init() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardWillShow(_:)),
      name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardWillHide(_:)),
      name: UIResponder.keyboardWillHideNotification, object: nil)
  }

  @objc private func keyboardWillShow(_ notification: Notification) {
    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
      as? CGRect
    {
      DispatchQueue.main.async {
        self.keyboardHeight = keyboardFrame.height - 20
      }
    }
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    DispatchQueue.main.async {
      self.keyboardHeight = 0
    }
  }
}
