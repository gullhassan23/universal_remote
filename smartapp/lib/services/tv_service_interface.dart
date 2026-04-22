import '../models/tv_brand.dart';
import '../models/tv_device.dart';

enum TvConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

enum CastMediaType {
  image,
  video,
  audio,
}

enum CastSessionState {
  idle,
  preparing,
  launching,
  displaying,
  failed,
  stopped,
}

class CastSessionUpdate {
  const CastSessionUpdate({
    required this.state,
    this.message,
  });

  final CastSessionState state;
  final String? message;
}

class CastMediaItem {
  CastMediaItem({
    required this.type,
    required this.filePath,
    required this.mimeType,
    this.title,
    this.sessionId,
    this.metadata = const <String, String>{},
  });

  final CastMediaType type;
  final String filePath;
  final String mimeType;
  final String? title;
  final String? sessionId;
  final Map<String, String> metadata;
}

abstract class ITvService {
  /// Discover TVs available on the network.
  ///
  /// If [filterBrand] is provided, the implementation should prefer or
  /// restrict discovery to that brand when possible. If null, it should
  /// discover all supported brands.
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand});

  Future<bool> connect(TvDevice device);

  Future<void> disconnect();

  Future<bool> sendKey(String key);

  /// Sends text using the best available input strategy for the active TV.
  ///
  /// Implementations should try direct IME commit first when possible and
  /// optionally prepare an input context (search/assistant) when needed.
  Future<bool> sendTextPrepared(
    String text, {
    bool autoPrepareInputContext = true,
  });

  Future<bool> launchApp(String packageName);

  Future<bool> castMedia(CastMediaItem item);

  Future<void> stopCasting();

  Stream<CastSessionUpdate> get castSessionStream;

  Stream<TvConnectionState> get connectionStateStream;
}