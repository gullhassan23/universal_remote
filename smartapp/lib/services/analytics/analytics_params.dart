/// Firebase Analytics event parameters must be [String] or [num] only.
Map<String, Object>? sanitizeEventParameters(Map<String, Object?>? params) {
  if (params == null) return null;
  return Map<String, Object>.fromEntries(
    params.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) => MapEntry(entry.key, _coerceParameterValue(entry.value!)),
        ),
  );
}

Object _coerceParameterValue(Object value) {
  if (value is String || value is num) return value;
  if (value is bool) return value ? 1 : 0;
  return value.toString();
}
