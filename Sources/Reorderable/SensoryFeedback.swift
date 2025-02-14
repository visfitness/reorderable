import SwiftUI

private struct DisableSensoryFeedbackEnvironmentKey: EnvironmentKey {
  static let defaultValue: Bool = false
}

extension EnvironmentValues {
  package var disableSensoryFeedback: Bool {
    get {
      self[DisableSensoryFeedbackEnvironmentKey.self]
    } set {
      self[DisableSensoryFeedbackEnvironmentKey.self] = newValue
    }
  }
}

extension View {
  /// Disables the sensory feedback of ``ReorderableHStack`` and ``ReorderableVStack``.
  ///
  /// - Parameters:
  ///     - disabled: A Boolean value that determines whether the sensory feedback is disabled.
  ///
  /// - A view that controls whether the sensory feeback of ``ReorderableHStack`` or ``ReorderableVStack`` is disabled.
  public func disableSensoryFeedback(_ disable: Bool = true) -> some View {
    self.environment(\.disableSensoryFeedback, disable)
  }
}
