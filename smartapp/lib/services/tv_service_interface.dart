import '../models/tv_device.dart';

enum TvConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

abstract class ITvService {
  Future<List<TvDevice>> discoverDevices();

  Future<bool> connect(TvDevice device);

  Future<void> disconnect();

  Future<bool> sendKey(String key);

  Stream<TvConnectionState> get connectionStateStream;
}

