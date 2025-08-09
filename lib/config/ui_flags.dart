/// UI Feature Flags (local, zero-risk)
/// Guard UI-only experiments that do not change backend/integrations.
/// Default all new flags to false for backward compatibility.
/// Lightweight UI logging helper used across widgets to avoid debug-only print scattering.
/// Kept here to avoid importing another util; no-op in release unless kDebugMode is true.
void logUi(String message) {
  assert(() {
    // Only runs in debug mode
    // Use a lightning emoji to align with delivery chip vibe for easy scanning
    // Avoid heavy string interpolation work unless actually logging
    // ignore: avoid_print
    print('⚡ UI: $message');
    return true;
  }());
}

class UiFlags {
  // Enables the compact title bar chip that shows "⚡ ETA • Location"
  // Must be safe to turn on/off at runtime without breaking existing flows.
  static const bool enableTitleBarLocationChip = false;

  // If true, will attempt an auto location fetch on app start
  // using existing AutoLocationService when the above chip is enabled.
  static const bool autoFetchLocationOnStartup = true;

  // Optional: show subtle debug border to verify placement quickly
  static const bool debugChipBorders = false;

  // Existing UI flags referenced across the app (provide defaults to avoid build breaks)
  static const bool enableCustomerBottomNav = true;
  static const bool compactLocationHeaderEnabled = true;
  static const bool categoryShortcutsEnabled = true;
  static const bool enableScrollCollapse = false;
}
