import SwiftUI

package let scrollCoordinatesSpaceName = "Scroll"

/// Attributes from the `ScrollView` to pass down to the `reorderable` so that it can autoscroll.
@available(iOS 18.0, macOS 15.0, *)
package struct AutoScrollContainerAttributes {
  let position: Binding<ScrollPosition>
  let bounds: CGSize
  let contentBounds: CGSize
  let offset: CGPoint
}

/// Key used to set and retrieve the `ScrollView` attributes from the environment.
@available(iOS 18.0, macOS 15.0, *)
private struct AutoScrollContainerAttributesEnvironmentKey: EnvironmentKey {
  static let defaultValue: AutoScrollContainerAttributes? = nil
}

@available(iOS 18.0, macOS 15.0, *)
extension EnvironmentValues {
  package var autoScrollContainerAttributes: AutoScrollContainerAttributes? {
    get { self[AutoScrollContainerAttributesEnvironmentKey.self] }
    set { self[AutoScrollContainerAttributesEnvironmentKey.self] = newValue }
  }
}

/// Information about the current scroll state.
///
/// This only exists to use as the "transformation" type for `onScrollGeometryChange`.
private struct ScrollInfo: Equatable {
  let bounds: CGSize
  let offset: CGPoint
}

/// View Modifier used to enable autoscrolling when the use user drags an element to the edge of the `ScrollView`.
@available(iOS 18.0, macOS 15.0, *)
private struct AutoScrollOnEdgesViewModifier: ViewModifier {
  @State var position: ScrollPosition = .init(idType: Never.self, x: 0.0, y: 0.0)
  @State var scrollContentBounds: ScrollInfo = ScrollInfo(bounds: CGSize.zero, offset: .zero)
  
  func body(content: Content) -> some View {
    GeometryReader { proxy in
      content
        .coordinateSpace(name: scrollCoordinatesSpaceName)
        .scrollPosition($position)
        .onScrollGeometryChange(for: ScrollInfo.self, of: {
          return ScrollInfo(bounds: $0.contentSize, offset: $0.contentOffset)
        }, action: { oldValue, newValue in
          if (scrollContentBounds != newValue) {
            scrollContentBounds = newValue
          }
        })
        .environment(
          \.autoScrollContainerAttributes,
           AutoScrollContainerAttributes(
            position: $position,
            bounds: proxy.size,
            contentBounds: scrollContentBounds.bounds,
            offset: scrollContentBounds.offset))
    }
  }
}

@available(iOS 18.0, macOS 10.15, *)
extension ScrollView {
  /// Enables the `ScrollView` to automatically scroll when the user drags an element from a ``ReorderableVStack`` or ``ReorderableHStack`` to its edges.
  ///
  /// Because ``Reorderable`` doesn't rely on SwiftUI's native `onDrag`, it also doesn't automatically trigger auto-scrolling when users drag the element to the edge of the parent/ancestor `ScrollView`. Applying this modifier to the `ScrollView` re-enables this behavior.
  public func autoScrollOnEdges() -> some View {
    modifier(AutoScrollOnEdgesViewModifier())
  }
}
