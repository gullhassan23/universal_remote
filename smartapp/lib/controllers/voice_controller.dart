import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';

import '../services/android_tv/android_tv_keycodes.dart';
import '../services/tv_service_interface.dart';
import 'remote_controller.dart';
import 'tv_connection_controller.dart';
import '../services/analytics_service.dart';

enum VoiceSessionState {
  idle,
  listening,
  processing,
  sending,
  sent,
  error,
}

class VoiceController extends GetxController {
  VoiceController({
    TvConnectionController? connectionController,
    RemoteController? remoteController,
    AnalyticsService? analyticsService,
  })
      : _connectionController =
            connectionController ?? Get.find<TvConnectionController>(),
        _remoteController = remoteController ?? Get.find<RemoteController>(),
        _analyticsService = analyticsService ?? Get.find<AnalyticsService>();

  final TvConnectionController _connectionController;
  final RemoteController _remoteController;
  final AnalyticsService _analyticsService;
  final SpeechToText _speech = SpeechToText();

  final Rx<VoiceSessionState> sessionState = VoiceSessionState.idle.obs;
  final RxBool isListening = false.obs;
  final RxString recognizedText = ''.obs;
  final RxString statusText = ''.obs;

  String _latestTranscript = '';
  String _lastSentText = '';
  bool _finalResultReceived = false;
  bool _hasSentForCurrentSession = false;
  bool _isFinalizing = false;
  bool _hasShownNoSpeechHint = false;
  Timer? _silenceFinalizeTimer;
  static const Duration _silenceFinalizeDelay = Duration(milliseconds: 1300);

  Future<void> startListening() async {
    if (isListening.value) return;
    unawaited(
      _analyticsService.logEvent(
        'voice_mic_start',
        params: <String, Object?>{
          'screen_name': 'VoiceController',
          'connection_state': _connectionController.connectionState.value.name,
        },
      ),
    );
    if (_connectionController.connectionState.value != TvConnectionState.connected) {
      _setErrorState('Connect to TV before using voice input.');
      return;
    }

    bool initialized = false;
    try {
      initialized = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
    } catch (error) {
      _setIdleState();
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
      _setIdleState();
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

    _latestTranscript = '';
    _lastSentText = '';
    _finalResultReceived = false;
    _hasSentForCurrentSession = false;
    _isFinalizing = false;
    _silenceFinalizeTimer?.cancel();
    recognizedText.value = '';
    statusText.value = 'Listening...';
    _hasShownNoSpeechHint = false;
    isListening.value = true;
    sessionState.value = VoiceSessionState.listening;

    await _speech.listen(
      onResult: _handleSpeechResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: Get.deviceLocale?.toLanguageTag(),
    );
  }

  Future<void> stopListening() async {
    if (!isListening.value) return;
    unawaited(
      _analyticsService.logEvent(
        'voice_mic_stop',
        params: <String, Object?>{
          'screen_name': 'VoiceController',
          'reason': 'manual_stop',
        },
      ),
    );
    _silenceFinalizeTimer?.cancel();
    sessionState.value = VoiceSessionState.processing;
    statusText.value = 'Processing speech...';
    await _speech.stop();
    isListening.value = false;
    await _finalizeAndSend(reason: 'manual_stop');
  }

  void onSpeechResult(String text) {
    final cleaned = text.trim();
    _latestTranscript = cleaned;
    recognizedText.value = cleaned;
    _scheduleSilenceFinalizeIfNeeded(cleaned);
  }

  Future<void> _handleSpeechResult(SpeechRecognitionResult result) async {
    onSpeechResult(result.recognizedWords);
    if (result.finalResult) {
      _finalResultReceived = true;
      await _finalizeAndSend(reason: 'final_result');
    }
  }

  Future<void> _onSpeechStatus(String status) async {
    if (status == 'done' || status == 'notListening') {
      _silenceFinalizeTimer?.cancel();
      isListening.value = false;
      unawaited(
        _analyticsService.logEvent(
          'voice_mic_status',
          params: <String, Object?>{
            'screen_name': 'VoiceController',
            'status': status,
          },
        ),
      );
      if (!_finalResultReceived) {
        await _finalizeAndSend(reason: status);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('VoiceController speech error: ${error.errorMsg}');
    }
    unawaited(
      _analyticsService.logEvent(
        'voice_mic_error',
        params: <String, Object?>{
          'screen_name': 'VoiceController',
          'error': error.errorMsg,
          'permanent': error.permanent,
        },
      ),
    );
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

    _setErrorState(error.errorMsg);
  }

  Future<void> _finalizeAndSend({required String reason}) async {
    if (_isFinalizing || _hasSentForCurrentSession) return;
    _isFinalizing = true;
    try {
      final text = _latestTranscript.trim();
      if (text.isEmpty) {
        unawaited(
          _analyticsService.logEvent(
            'voice_transcript_empty',
            params: <String, Object?>{
              'screen_name': 'VoiceController',
              'reason': reason,
            },
          ),
        );
        _setErrorState('No speech detected. Please try again.');
        return;
      }
      if (text == _lastSentText) {
        unawaited(
          _analyticsService.logEvent(
            'voice_transcript_duplicate',
            params: <String, Object?>{
              'screen_name': 'VoiceController',
              'reason': reason,
            },
          ),
        );
        sessionState.value = VoiceSessionState.sent;
        statusText.value = 'Already sent.';
        return;
      }
      sessionState.value = VoiceSessionState.sending;
      statusText.value = 'Sending to TV...';

      var sent = await _remoteController.sendPreparedTextReliably(
        text,
        openPickerOnFailure: false,
        autoPrepareInputContext: true,
        source: 'mobile_voice',
      );
      if (!sent) {
        sent = await _sendPerKeyFallback(text);
      }
      if (!sent) {
        unawaited(
          _analyticsService.logEvent(
            'voice_send_failed',
            params: <String, Object?>{
              'screen_name': 'VoiceController',
              'reason': reason,
              'length': text.length,
            },
          ),
        );
        _setErrorState(
          'Could not send voice text to TV. Search will open automatically when supported.',
        );
        return;
      }

      _lastSentText = text;
      _hasSentForCurrentSession = true;
      unawaited(
        _analyticsService.logEvent(
          'voice_send_success',
          params: <String, Object?>{
            'screen_name': 'VoiceController',
            'reason': reason,
            'length': text.length,
          },
        ),
      );
      sessionState.value = VoiceSessionState.sent;
      statusText.value = 'Sent to TV';
      if (kDebugMode) {
        // ignore: avoid_print
        print('VoiceController sent transcript reason=$reason text="$text"');
      }
    } finally {
      _isFinalizing = false;
    }
  }

  void _scheduleSilenceFinalizeIfNeeded(String transcript) {
    if (!isListening.value || transcript.isEmpty || _finalResultReceived) {
      return;
    }
    _silenceFinalizeTimer?.cancel();
    _silenceFinalizeTimer = Timer(_silenceFinalizeDelay, () async {
      if (!isListening.value || _isFinalizing) return;
      sessionState.value = VoiceSessionState.processing;
      statusText.value = 'Processing speech...';
      await _speech.stop();
      isListening.value = false;
      await _finalizeAndSend(reason: 'silence_timeout');
    });
  }

  Future<bool> _sendPerKeyFallback(String text) async {
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final mapped = mapTypedCharToRemoteKey(char);
      if (mapped == null) {
        continue;
      }
      final sent = await _connectionController.sendKey(mapped);
      if (!sent) {
        return false;
      }
    }
    return true;
  }

  void _setErrorState(String message) {
    isListening.value = false;
    sessionState.value = VoiceSessionState.error;
    statusText.value = message;
    Get.snackbar('Voice', message, snackPosition: SnackPosition.BOTTOM);
  }

  void _setIdleState() {
    isListening.value = false;
    sessionState.value = VoiceSessionState.idle;
    statusText.value = '';
  }

  @override
  void onClose() {
    _silenceFinalizeTimer?.cancel();
    _speech.cancel();
    super.onClose();
  }
}
