import 'package:flutter/foundation.dart';

class CompanionTvService {
  static const bool _featureEnabled = bool.fromEnvironment(
    'ENABLE_TV_COMPANION',
    defaultValue: false,
  );

  bool get isFeatureEnabled => _featureEnabled;

  Future<bool> isReachable() async {
    // Companion transport handshake will be implemented in the companion phase.
    return false;
  }

  Future<bool> sendVoiceText({
    required String text,
    required String source,
  }) async {
    if (!_featureEnabled || text.trim().isEmpty) {
      return false;
    }
    debugPrint(
      'CompanionTvService.sendVoiceText pending implementation source=$source length=${text.length}',
    );
    return false;
  }
}
