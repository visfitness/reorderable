import SwiftUI

/// Abstract representation of the position of an element along an Axis. Used to abstract computations of the positions across vertical and horizontal stacks.
package protocol AxisPosition: Equatable{
  associatedtype Preference: PreferenceKey where Preference.Value == Self
  
  init(_ rect: CGRect)
  
  var min: CGFloat { get }
  var max: CGFloat { get }
  
  func contains(_ val: CGFloat) -> Bool
  
  var span: CGFloat { get }
}

extension AxisPosition {
  /// Whether the value is within the element alongside the specific axis.
  package func contains(_ val: CGFloat) -> Bool {
    return min <= val && val <= max
  }
  
  /// The length of the elemement alongside the specific axis.
  package var span: CGFloat {
    return max - min
  }
}

package struct VerticalPositionPreferenceKey: PreferenceKey {
  package static var defaultValue: VerticalPosition { .init(.zero) }
  
  package static func reduce(value: inout VerticalPosition, nextValue: () -> VerticalPosition) {
    value = nextValue()
  }
}

package struct VerticalPosition: AxisPosition {
  package typealias Preference = VerticalPositionPreferenceKey
  
  package let min: CGFloat
  package let max: CGFloat
  
  package init(_ rect: CGRect) {
    min = rect.minY
    max = rect.maxY
  }
}

package struct HorizontalPositionPreferenceKey: PreferenceKey {
  package static var defaultValue: HorizontalPosition { .init(.zero) }
  
  package static func reduce(value: inout HorizontalPosition, nextValue: () -> HorizontalPosition) {
    value = nextValue()
  }
}

package struct HorizontalPosition: AxisPosition {
  package typealias Preference = HorizontalPositionPreferenceKey
  
  package let min: CGFloat
  package let max: CGFloat
  
  package init(_ rect: CGRect) {
    min = rect.minX
    max = rect.maxX
  }
}
