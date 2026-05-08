class AnalyticsDedupe {
  AnalyticsDedupe({
    required this.minIntervalMs,
    this.maxEntries = 128,
  });

  final int minIntervalMs;
  final int maxEntries;

  final Map<String, int> _lastSeenMsByKey = <String, int>{};

  bool shouldDrop(String key, int nowMs) {
    final last = _lastSeenMsByKey[key];
    if (last != null && (nowMs - last) < minIntervalMs) {
      return true;
    }
    _lastSeenMsByKey[key] = nowMs;
    if (_lastSeenMsByKey.length > maxEntries) {
      // Simple eviction: remove oldest by timestamp.
      String? oldestKey;
      var oldestTs = 1 << 62;
      for (final entry in _lastSeenMsByKey.entries) {
        if (entry.value < oldestTs) {
          oldestTs = entry.value;
          oldestKey = entry.key;
        }
      }
      if (oldestKey != null) {
        _lastSeenMsByKey.remove(oldestKey);
      }
    }
    return false;
  }
}

