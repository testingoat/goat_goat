import 'package:flutter/foundation.dart';

/// Central place to toggle lightweight UI experiments safely at runtime.
/// In production, you can replace these with Remote Config values.
class UiFlags {
  static const bool categoryShortcutsEnabled = true;

  /// Feature flag to enable the bottom navigation shell for customers.
  /// UI-only: toggles which scaffold hosts the screens, no business logic changes.
  static const bool enableCustomerBottomNav = true;

  /// Feature flag to enable the compact location header (two-row design)
  /// Replaces the large location bar with compact status + search rows
  /// Phase 1: Basic two-row layout with feature flag
  static const bool compactLocationHeaderEnabled = true;

  /// Feature flag to enable scroll-collapsing behavior for compact header
  /// Phase 2: Advanced scroll behavior (now enabled)
  static const bool enableScrollCollapse = true;
}

/// Helper to log UI feature usage in debug builds only.
void logUi(String message) {
  if (kDebugMode) {
    // Use print to avoid adding dependencies; swap for analytics as needed.
    // Intentionally concise for low overhead.
    // Example: logUi('Category shortcut tapped: Seafood');
    // ignore: avoid_print
    print('UI » $message');
  }
}
