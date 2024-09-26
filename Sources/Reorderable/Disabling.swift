import SwiftUI

private struct DragDisabledEnvironmentKey: EnvironmentKey {
  static let defaultValue: Bool = false
}


extension EnvironmentValues {
  package var dragDisabled: Bool {
    get { self[DragDisabledEnvironmentKey.self] }
    set { self[DragDisabledEnvironmentKey.self] = newValue }
  }
}

private struct DragDisabledViewModifier: ViewModifier {
  let disableDrag: Bool
  
  func body(content: Content) -> some View {
    content
      .environment(\.dragDisabled, disableDrag)
  }
}

extension ReorderableVStack {
  /// Adds a condition that controls whether users can drag elements of this view.
  ///
  /// - Parameters:
  ///    - dragDisabled: A Boolean value that determines whether users can drag elements of this view.
  ///
  /// - Returns: A view that controls whether users can drag elements of this view.
  public func dragDisabled(_ dragDisabled: Bool) -> some View {
    modifier(DragDisabledViewModifier(disableDrag: dragDisabled))
  }
}
