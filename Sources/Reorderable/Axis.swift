import Foundation

package protocol ContainerAxis {
  associatedtype Position: AxisPosition
  
  static func project(point: CGPoint) -> CGFloat
  static func project(maybePoint: CGPoint?) -> CGFloat?
  static func project(size: CGSize) -> CGFloat
  static func asPoint(value: CGFloat) -> CGPoint
  static func asSize(value: CGFloat) -> CGSize
}

package struct VerticalContainerAxis: ContainerAxis {
  public typealias Position = VerticalPosition
  
  package static func project(point: CGPoint) -> CGFloat {
    point.y
  }
  
  package static func project(maybePoint: CGPoint?) -> CGFloat? {
    maybePoint?.y
  }
  
  package static func project(size: CGSize) -> CGFloat {
    .init(size.height)
  }
  
  package static func asPoint(value: CGFloat) -> CGPoint {
    .init(x: 0, y: value)
  }
  
  package static func asSize(value: CGFloat) -> CGSize {
    .init(width: 0, height: value)
  }
}

package struct HorizontalContainerAxis: ContainerAxis {
  public typealias Position = HorizontalPosition
  
  package static func project(point: CGPoint) -> CGFloat {
    point.x
  }
  
  package static func project(maybePoint: CGPoint?) -> CGFloat? {
    maybePoint?.x
  }
  
  package static func project(size: CGSize) -> CGFloat {
    .init(size.width)
  }
  
  package static func asPoint(value: CGFloat) -> CGPoint {
    .init(x: value, y: 0)
  }
  
  package static func asSize(value: CGFloat) -> CGSize {
    .init(width: value, height: 0)
  }
}
