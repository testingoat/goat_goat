import 'package:flutter/foundation.dart';

/// Central place to toggle lightweight UI experiments safely at runtime.
/// In production, you can replace these with Remote Config values.
class UiFlags {
  static const bool categoryShortcutsEnabled = true;
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