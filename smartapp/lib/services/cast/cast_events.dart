import '../../models/tv_device.dart';
import '../tv_service_interface.dart';

enum CastEventType {
  deviceList,
  connectDevice,
  startCast,
  sendMedia,
}

class CastEvent<TPayload> {
  const CastEvent({
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final CastEventType type;
  final TPayload payload;
  final DateTime createdAt;
}

class DeviceListEventPayload {
  const DeviceListEventPayload({required this.devices});

  final List<TvDevice> devices;
}

class ConnectDeviceEventPayload {
  const ConnectDeviceEventPayload({
    required this.device,
    required this.success,
  });

  final TvDevice device;
  final bool success;
}

class StartCastEventPayload {
  const StartCastEventPayload({
    required this.sessionId,
    required this.device,
  });

  final String sessionId;
  final TvDevice device;
}

class SendMediaEventPayload {
  const SendMediaEventPayload({
    required this.sessionId,
    required this.item,
    required this.success,
  });

  final String sessionId;
  final CastMediaItem item;
  final bool success;
}
