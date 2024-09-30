/// This file contains the components responsible for disabling and enabling the dragging of the stacks.

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
  /// Adds a condition that controls whether users can drag elements of this `ReorderableVStack`.
  ///
  /// - Parameters:
  ///    - dragDisabled: A Boolean value that determines whether users can drag elements of this `ReorderableVStack`.
  ///
  /// - Returns: A view that controls whether users can drag elements of this `ReorderableVStack`.
  public func dragDisabled(_ dragDisabled: Bool) -> some View {
    modifier(DragDisabledViewModifier(disableDrag: dragDisabled))
  }
}

extension ReorderableHStack {
  /// Adds a condition that controls whether users can drag elements of this `ReorderableHStack`.
  ///
  /// - Parameters:
  ///    - dragDisabled: A Boolean value that determines whether users can drag elements of this `ReorderableHStack`.
  ///
  /// - Returns: A view that controls whether users can drag elements of this `ReorderableHStack`.
  public func dragDisabled(_ dragDisabled: Bool) -> some View {
    modifier(DragDisabledViewModifier(disableDrag: dragDisabled))
  }
}
