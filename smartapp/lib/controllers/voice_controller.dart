import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/android_tv/android_tv_keycodes.dart';
import 'tv_connection_controller.dart';

class VoiceController extends GetxController {
  VoiceController({TvConnectionController? connectionController})
      : _connectionController =
            connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;
  final SpeechToText _speech = SpeechToText();

  final RxBool isListening = false.obs;
  final RxString recognizedText = ''.obs;

  String _lastSentText = '';
  Future<void> _sendQueue = Future<void>.value();
  bool _hasShownNoSpeechHint = false;

  Future<void> startListening() async {
    if (isListening.value) return;

    bool initialized = false;
    try {
      initialized = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
    } catch (error) {
      _resetVoiceState();
      Get.snackbar(
        'Voice unavailable',
        'Failed to initialize speech service. Please try again.',
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('VoiceController initialize failed: $error');
      }
      return;
    }

    if (!initialized) {
      _resetVoiceState();
      final permissionDenied = _speech.hasPermission != true;
      final message = permissionDenied
          ? 'Microphone permission is denied. Enable it in system settings and try again.'
          : 'Speech service is unavailable on this device.';
      Get.snackbar(
        'Voice unavailable',
        message,
      );
      return;
    }

    _lastSentText = '';
    recognizedText.value = '';
    _hasShownNoSpeechHint = false;
    isListening.value = true;

    await _speech.listen(
      onResult: _handleSpeechResult,
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: Get.deviceLocale?.toLanguageTag(),
    );
  }

  Future<void> stopListening() async {
    if (!isListening.value) return;
    await _speech.stop();
    isListening.value = false;
  }

  void onSpeechResult(String text) {
    final cleaned = text.trim();
    recognizedText.value = cleaned;
    _enqueueDeltaSend(cleaned);
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    onSpeechResult(result.recognizedWords);
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      isListening.value = false;
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('VoiceController speech error: ${error.errorMsg}');
    }
    final msg = error.errorMsg.toLowerCase();
    final isNoSpeechTimeout = msg.contains('error_speech_timeout') ||
        msg.contains('no match') ||
        msg.contains('timeout');

    if (isNoSpeechTimeout) {
      // This is common when user presses mic but waits before speaking.
      if (!_hasShownNoSpeechHint) {
        _hasShownNoSpeechHint = true;
        Get.snackbar(
          'Voice',
          'Mic on hai. Bolna start karein ya mic dobara tap karein.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    _resetVoiceState();
    Get.snackbar('Voice error', error.errorMsg);
  }

  void _enqueueDeltaSend(String latest) {
    _sendQueue = _sendQueue.then((_) => _sendDelta(latest));
  }

  Future<void> _sendDelta(String latest) async {
    if (latest == _lastSentText) return;

    final sentAsBatch = await _sendTypedKey('__TEXT__:$latest');
    if (sentAsBatch) {
      _lastSentText = latest;
      return;
    }

    final previous = _lastSentText;
    var commonPrefixLength = 0;
    final maxPrefix = previous.length < latest.length ? previous.length : latest.length;
    while (commonPrefixLength < maxPrefix &&
        previous.codeUnitAt(commonPrefixLength) == latest.codeUnitAt(commonPrefixLength)) {
      commonPrefixLength++;
    }

    final backspaces = previous.length - commonPrefixLength;
    for (var i = 0; i < backspaces; i++) {
      await _sendTypedKey('KEY_BACKSPACE');
    }

    final delta = latest.substring(commonPrefixLength);
    for (final rune in delta.runes) {
      final char = String.fromCharCode(rune);
      final mapped = mapTypedCharToRemoteKey(char);
      if (mapped == null) {
        continue;
      }
      await _sendTypedKey(mapped);
    }

    _lastSentText = latest;
  }

  Future<bool> _sendTypedKey(String key) async {
    // Voice typing should not trigger device picker UI; send directly.
    var ok = await _connectionController.sendKey(key);
    if (ok) return true;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    ok = await _connectionController.sendKey(key);
    if (!ok && kDebugMode) {
      // ignore: avoid_print
      print('VoiceController failed to send key: $key');
    }
    return ok;
  }

  void _resetVoiceState() {
    isListening.value = false;
  }

  @override
  void onClose() {
    _speech.cancel();
    super.onClose();
  }
}
