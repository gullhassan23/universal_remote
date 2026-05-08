class EventNaming {
  static String sanitizeToken(String value) {
    final compact = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return compact;
  }

  /// Firebase event name constraints are stricter than GA.
  /// - lower_snake_case
  /// - <= 40 chars
  /// - cannot start with a number
  /// - avoid reserved prefixes like firebase_/google_/ga_
  static String normalizeFirebaseEventName(String value) {
    final token = sanitizeToken(value).toLowerCase();
    var normalized = token.isEmpty ? 'app_event' : token;
    if (RegExp(r'^[0-9]').hasMatch(normalized)) {
      normalized = 'e_$normalized';
    }
    if (normalized.startsWith('firebase_') ||
        normalized.startsWith('google_') ||
        normalized.startsWith('ga_')) {
      normalized = 'app_$normalized';
    }
    if (normalized.length > 40) {
      normalized = normalized.substring(0, 40).replaceAll(RegExp(r'_+$'), '');
      if (normalized.isEmpty) {
        normalized = 'app_event';
      }
    }
    return normalized;
  }

  /// GameAnalytics design event IDs are colon-separated and should stay
  /// low-cardinality (stable tokens only).
  static String gaDesignIdFromEventName(String name) {
    final raw = name.trim();
    if (raw.isEmpty) return 'ui:event';

    // Prefer mapping common patterns to predictable trees.
    if (raw.startsWith('screen_')) {
      final tail = raw.substring('screen_'.length);
      final token = sanitizeToken(tail);
      return token.isEmpty ? 'screen:unknown' : 'screen:$token';
    }
    if (raw.startsWith('click_')) {
      final tail = raw.substring('click_'.length);
      final token = sanitizeToken(tail);
      return token.isEmpty ? 'ui:click:unknown' : 'ui:click:$token';
    }
    if (raw.startsWith('nav_')) {
      final tail = raw.substring('nav_'.length);
      final token = sanitizeToken(tail);
      return token.isEmpty ? 'nav:unknown' : 'nav:$token';
    }
    if (raw.startsWith('tab_')) {
      final tail = raw.substring('tab_'.length);
      final token = sanitizeToken(tail);
      return token.isEmpty ? 'ui:tab:unknown' : 'ui:tab:$token';
    }

    // Default: map snake_case or arbitrary names into `app:<Token>`.
    final token = sanitizeToken(raw);
    return token.isEmpty ? 'app:event' : 'app:$token';
  }
}

