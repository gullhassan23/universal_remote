import '../models/tv_brand.dart';
import '../models/tv_device.dart';

enum TvConnectionState {
  disconnected,
  connecting,
  connected,
  error,
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

  Stream<TvConnectionState> get connectionStateStream;
}

