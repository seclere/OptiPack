import Foundation
import SwiftData

@Model
class ContainerDetails {
  var containerWidth: Float
  var containerHeight: Float
  var containerDepth: Float
  var containerMaximumWeight: Float

  init(
    containerWidth: String, containerHeight: String, containerDepth: String,
    containerMaximumWeight: String
  ) {
    self.containerWidth = Float(containerWidth) ?? 0
    self.containerHeight = Float(containerHeight) ?? 0
    self.containerDepth = Float(containerDepth) ?? 0
    self.containerMaximumWeight = Float(containerMaximumWeight) ?? 0
  }
}
