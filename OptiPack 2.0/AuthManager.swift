//
//  AuthManager.swift
//  OptiPack 2.0
//
//  Created by Ysrael Salces on 5/21/25.
//

import Foundation
import SwiftData

class AuthManager: ObservableObject {
  @Published var currentUser: UserCredentials?

  func signIn(email: String, password: String, modelContext: ModelContext) {
    let fetchDescriptor = FetchDescriptor<UserCredentials>(
      predicate: #Predicate { $0.email == email && $0.password == password }
    )
    if let user = try? modelContext.fetch(fetchDescriptor).first {
      self.currentUser = user
    }
  }

  func signOut() {
    currentUser = nil
  }
}
