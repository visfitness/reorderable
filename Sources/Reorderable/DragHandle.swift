import SwiftUI

@available(iOS 18.0, *)
package struct DragCallbacks {
  let onDrag: (_ stackDrag: DragGesture.Value, _ scrollDrag: DragGesture.Value) -> Void
  let onDrop: (_ stackDrag: DragGesture.Value) -> Void

  let dragCoordinatesSpaceName: String
  let isEnabled: Bool
}

@available(iOS 18.0, *)
private struct DragCallbackKey: @preconcurrency EnvironmentKey {
  @MainActor static let defaultValue: DragCallbacks = .init(onDrag: { _, __ in }, onDrop: { _ in }, dragCoordinatesSpaceName: "", isEnabled: false)
}

@available(iOS 18.0, *)
extension EnvironmentValues {
  package var reorderableDragCallback: DragCallbacks {
        get { self[DragCallbackKey.self] }
        set { self[DragCallbackKey.self] = newValue }
    }
}

private struct HasDragHandlePreferenceKey: PreferenceKey {
  static var defaultValue: Bool { false }
  
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

@available(iOS 18.0, *)
struct DragHandleViewModifier: ViewModifier {
  @Environment(\.reorderableDragCallback) private var dragCallbacks
  @State var alreadyHasDragHandle: Bool = false
  
  func body(content: Content) -> some View {
    content
      .onPreferenceChange(HasDragHandlePreferenceKey.self) { alreadyHasDragHandle = $0 }
      .gesture(
        SimultaneousGesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .named(dragCallbacks.dragCoordinatesSpaceName)),
          DragGesture(minimumDistance: 0, coordinateSpace: .named(scrollCoordinatesSpaceName)))
          .onChanged { values in
            // Putting these here seems to garantee the execution order
            // which eliminates some of the jiggle.
            dragCallbacks.onDrag(values.first!, values.second!)
          }
          .onEnded { values in
            dragCallbacks.onDrag(values.first!, values.second!)
            dragCallbacks.onDrop(values.first!)
          },
        isEnabled: dragCallbacks.isEnabled && !alreadyHasDragHandle)
      .preference(key: HasDragHandlePreferenceKey.self, value: true)
  }
}

@available(iOS 18.0, *)
extension View {
  /// Makes this view the handle for dragging the element of the closest `ReorderableVStack` or `ReorderableHStack`.
  ///
  /// Settings this on a subview of the element will make it the only way to move the element around.
  public func dragHandle() -> some View {
    modifier(DragHandleViewModifier())
  }
}
