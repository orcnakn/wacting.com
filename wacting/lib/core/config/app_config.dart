/// Wacting — Centralized Environment Configuration
///
/// Switch between development (mock/local) and production (live VDS) modes.
/// Before building for production: set [isProduction] to true.

class AppConfig {
  // ─────────────────────────────────────────────────────────────────────────
  // BUILD MODE — flip to true before `flutter build web --release`
  // ─────────────────────────────────────────────────────────────────────────
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);

  // ─────────────────────────────────────────────────────────────────────────
  // URLS
  // ─────────────────────────────────────────────────────────────────────────

  /// REST API base URL
  static String get apiBaseUrl => isProduction
      ? 'https://api.wacting.com'
      : 'http://127.0.0.1:3000';

  /// WebSocket server URL
  static String get socketUrl => isProduction
      ? 'https://api.wacting.com'
      : 'http://127.0.0.1:3000';

  /// Flutter web origin (used for CORS reference)
  static String get webOrigin => isProduction
      ? 'https://wacting.com'
      : 'http://localhost:8080';

  // ─────────────────────────────────────────────────────────────────────────
  // APP INFO
  // ─────────────────────────────────────────────────────────────────────────
  static const String appName    = 'Wacting';
  static const String appVersion = '1.0.0';
}
