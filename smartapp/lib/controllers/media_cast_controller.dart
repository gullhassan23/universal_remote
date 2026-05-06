import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cast/chromecast_cast_service.dart';
import '../services/media/local_media_server.dart';
import 'tv_connection_controller.dart';

enum MediaCastStatus {
  idle,
  selectingTarget,
  picking,
  casting,
  success,
  error,
}

class CastMediaItem {
  const CastMediaItem({
    required this.path,
    required this.name,
    required this.mimeType,
  });

  final String path;
  final String name;
  final String mimeType;

  bool get isVideo => mimeType.startsWith('video/');
}

class MediaCastController extends GetxController {
  MediaCastController({
    TvConnectionController? connectionController,
    ChromecastCastService? castService,
  }) : _castService = castService ?? ChromecastCastService();
  final ImagePicker _imagePicker = ImagePicker();
  final ChromecastCastService _castService;
  final Rx<MediaCastStatus> status = MediaCastStatus.idle.obs;
  final RxString errorMessage = ''.obs;
  final RxString progressMessage = ''.obs;
  final RxString connectedDeviceName = ''.obs;
  final RxBool isConnecting = false.obs;
  final RxBool connectionLocked = false.obs;
  final RxList<CastMediaItem> mediaQueue = <CastMediaItem>[].obs;
  final RxInt currentMediaIndex = 0.obs;
  final RxInt mediaVersion = 0.obs;
  final LocalMediaServer _mediaServer = LocalMediaServer();
  CastMediaItem? _activeMedia;
  GoogleCastDevice? _selectedDevice;
  bool _manualDisconnectRequested = false;
  Timer? _connectionMonitorTimer;

  @override
  void onInit() {
    super.onInit();
  }

  bool get hasMedia => mediaQueue.isNotEmpty;
  bool get isCastingActive =>
      hasMedia &&
      (status.value == MediaCastStatus.casting ||
          status.value == MediaCastStatus.success);
  bool get hasPersistentSession =>
      _selectedDevice != null &&
      _castService.connectionState == GoogleCastConnectState.connected;
  bool get shouldKeepConnectionAlive =>
      connectionLocked.value && !_manualDisconnectRequested;

  CastMediaItem? get currentMedia {
    if (mediaQueue.isEmpty) return null;
    final index = currentMediaIndex.value.clamp(0, mediaQueue.length - 1);
    return mediaQueue[index];
  }

  Future<void> pickAndCastMedia() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _setError('Media casting is currently unavailable on this device.');
      return;
    }

    try {
      errorMessage.value = '';
      await _castService.ensureContextInitialized();

      final connected = await ensureConnectedForCasting();
      if (!connected) return;

      status.value = MediaCastStatus.picking;
      progressMessage.value = 'Select media from gallery...';
      final pickedItems = await _pickMediaFromGallery();
      if (pickedItems.isEmpty) {
        _resetToIdle();
        return;
      }

      final nextQueue = <CastMediaItem>[];
      for (final selected in pickedItems) {
        final path = selected.path;
        final mimeType = _inferMimeType(path);
        if (!(mimeType.startsWith('image/') || mimeType.startsWith('video/'))) {
          continue;
        }
        nextQueue.add(
          CastMediaItem(
            path: path,
            name: selected.name,
            mimeType: mimeType,
          ),
        );
      }
      if (nextQueue.isEmpty) {
        _setError('Please select a supported image or video file.');
        return;
      }

      mediaQueue.assignAll(nextQueue);
      currentMediaIndex.value = 0;
      mediaVersion.value++;

      await castMediaAt(0);
      if (connectedDeviceName.value.isNotEmpty) {
        Get.snackbar(
          'Casting started',
          'Connected to ${connectedDeviceName.value}. Swipe to switch media instantly.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Media cast error: $error');
      debugPrint('$stackTrace');
      _setError('Casting failed. Please try again.');
    }
  }

  /// Returns `true` only when casting successfully starts (i.e. ends in [MediaCastStatus.success]).
  ///
  /// This is used by rewarded-gated features to consume an entitlement only after a successful cast.
  Future<bool> pickAndCastMediaWithResult() async {
    final int startVersion = mediaVersion.value;
    final MediaCastStatus startStatus = status.value;
    final String startError = errorMessage.value;

    await pickAndCastMedia();

    if (status.value == MediaCastStatus.success) {
      // If status was already success before and nothing changed, treat it as not a new success.
      final bool noChange =
          mediaVersion.value == startVersion &&
          startStatus == MediaCastStatus.success &&
          errorMessage.value == startError;
      return !noChange;
    }
    return false;
  }

  Future<void> pickAndCastImage() async {
    await pickAndCastMedia();
  }

  Future<void> castMediaAt(int index) async {
    if (mediaQueue.isEmpty || index < 0 || index >= mediaQueue.length) return;
    if (!hasPersistentSession) {
      final connected = await ensureConnectedForCasting();
      if (!connected) return;
    }

    final media = mediaQueue[index];
    currentMediaIndex.value = index;
    _activeMedia = media;
    mediaVersion.value++;

    final mediaUri = await _serveCurrentMedia();
    if (mediaUri == null) {
      _setError('Failed to prepare media for casting on local network.');
      return;
    }

    status.value = MediaCastStatus.casting;
    progressMessage.value = connectedDeviceName.value.isEmpty
        ? 'Casting media...'
        : 'Casting on ${connectedDeviceName.value} (${index + 1}/${mediaQueue.length})...';

    await _castService.loadMedia(
      mediaUri: mediaUri,
      mimeType: media.mimeType,
      title: media.name,
    );

    status.value = MediaCastStatus.success;
    progressMessage.value = connectedDeviceName.value.isEmpty
        ? 'Casting active.'
        : 'Connected to ${connectedDeviceName.value}. Showing ${index + 1}/${mediaQueue.length}.';
  }

  Future<void> castNext() async {
    if (mediaQueue.isEmpty) return;
    final next = (currentMediaIndex.value + 1).clamp(0, mediaQueue.length - 1);
    if (next == currentMediaIndex.value) return;
    await castMediaAt(next);
  }

  Future<void> castPrevious() async {
    if (mediaQueue.isEmpty) return;
    final previous = (currentMediaIndex.value - 1).clamp(0, mediaQueue.length - 1);
    if (previous == currentMediaIndex.value) return;
    await castMediaAt(previous);
  }

  Future<void> disconnectSession() async {
    _manualDisconnectRequested = true;
    connectionLocked.value = false;
    await _ensureSessionDisconnected();
    _selectedDevice = null;
    connectedDeviceName.value = '';
    _stopConnectionMonitor();
    _resetToIdle();
  }

  Future<void> stopCastingAndReset() async {
    await disconnectSession();
    mediaQueue.clear();
    currentMediaIndex.value = 0;
    _activeMedia = null;
    mediaVersion.value++;
  }

  Future<bool> ensureConnectedForCasting() async {
    if (hasPersistentSession) {
      connectionLocked.value = true;
      return true;
    }
    return _connectToCastDevice();
  }

  Future<List<_PickedMediaEntry>> _pickMediaFromGallery() async {
    final mode = await Get.bottomSheet<_GalleryPickMode>(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Select photos'),
                subtitle: const Text('Choose one or more images'),
                onTap: () => Get.back(result: _GalleryPickMode.images),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Select video'),
                subtitle: const Text('Choose a video from gallery'),
                onTap: () => Get.back(result: _GalleryPickMode.video),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Get.back(result: _GalleryPickMode.cancel),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );

    if (mode == null || mode == _GalleryPickMode.cancel) {
      return <_PickedMediaEntry>[];
    }

    if (mode == _GalleryPickMode.images) {
      final files = await _imagePicker.pickMultiImage();
      return files
          .map(
            (file) => _PickedMediaEntry(
              path: file.path,
              name: file.name.isEmpty ? 'Image' : file.name,
            ),
          )
          .toList();
    }

    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return <_PickedMediaEntry>[];
    }
    return <_PickedMediaEntry>[
      _PickedMediaEntry(
        path: file.path,
        name: file.name.isEmpty ? 'Video' : file.name,
      ),
    ];
  }

  Future<GoogleCastDevice?> _selectDevice(List<GoogleCastDevice> devices) async {
    if (devices.length == 1) {
      return devices.first;
    }

    final device = await Get.bottomSheet<GoogleCastDevice>(
      Container(
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Select a cast device',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (_, index) {
                    final item = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.cast),
                      title: Text(item.friendlyName),
                      subtitle: Text(item.modelName ?? 'Cast device'),
                      onTap: () => Get.back<GoogleCastDevice>(result: item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );

    return device;
  }

  Future<Uri?> _serveCurrentMedia() async {
    final media = _activeMedia;
    if (media == null) return null;
    final mediaFile = File(media.path);
    if (!await mediaFile.exists()) {
      return null;
    }

    final session = await _mediaServer.serveFile(
      filePath: media.path,
      mimeType: media.mimeType,
      sessionId: 'chromecast-${DateTime.now().millisecondsSinceEpoch}',
      requireViewerHandshake: false,
    );
    return session?.mediaUri;
  }

  @override
  void onClose() {
    unawaited(_mediaServer.stop());
    _castService.stopDiscovery();
    _stopConnectionMonitor();
    super.onClose();
  }

  void _setError(String message) {
    status.value = MediaCastStatus.error;
    errorMessage.value = message;
    progressMessage.value = '';
    Get.snackbar('Media cast', message);
  }

  void _resetToIdle() {
    status.value = MediaCastStatus.idle;
    progressMessage.value = '';
  }

  Future<bool> _connectToCastDevice() async {
    if (isConnecting.value) return false;
    isConnecting.value = true;
    status.value = MediaCastStatus.selectingTarget;
    progressMessage.value = 'Searching for cast devices...';
    _castService.startDiscovery();
    _manualDisconnectRequested = false;

    try {
      final discoveryTimeout = Platform.isIOS
          ? const Duration(seconds: 25)
          : const Duration(seconds: 15);
      final devices = await _castService.discoverDevices(timeout: discoveryTimeout);
      if (devices.isEmpty) {
        _setError(
          Platform.isIOS
              ? 'No cast devices found. Allow Local Network access for this app in Settings, then retry on the same Wi-Fi.'
              : 'No cast devices found on this Wi-Fi network.',
        );
        return false;
      }

      final selectedDevice = await _selectDevice(devices);
      if (selectedDevice == null) {
        _resetToIdle();
        return false;
      }

      progressMessage.value = 'Connecting to ${selectedDevice.friendlyName}...';
      final connectionState = await _connectToDeviceWithRetry(selectedDevice);
      if (connectionState != GoogleCastConnectState.connected) {
        _setError('Could not connect to ${selectedDevice.friendlyName}.');
        return false;
      }

      _selectedDevice = selectedDevice;
      connectedDeviceName.value = selectedDevice.friendlyName;
      connectionLocked.value = true;
      _startConnectionMonitor();
      return true;
    } finally {
      _castService.stopDiscovery();
      isConnecting.value = false;
    }
  }

  Future<void> _ensureSessionDisconnected() async {
    if (_castService.connectionState == GoogleCastConnectState.connected) {
      await _castService.endSessionAndStopCasting();
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  Future<GoogleCastConnectState> _connectToDeviceWithRetry(
    GoogleCastDevice selectedDevice,
  ) async {
    if (_canReuseConnectedSession(selectedDevice)) {
      return GoogleCastConnectState.connected;
    }
    // Some devices (especially Mi TV Stick) take longer to expose a
    // fully connected cast session.
    const maxAttempts = 2;
    var lastState = _castService.connectionState;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await _disconnectForReconnectIfNeeded(selectedDevice);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _castService.startSessionWithDevice(selectedDevice);

      progressMessage.value = attempt == 1
          ? 'Waiting for ${selectedDevice.friendlyName} to accept cast session...'
          : 'Retrying connection to ${selectedDevice.friendlyName}...';
      lastState = await _castService.waitForConnectedSession();
      if (lastState == GoogleCastConnectState.connected) {
        return lastState;
      }
    }
    return lastState;
  }

  bool _canReuseConnectedSession(GoogleCastDevice device) {
    final isConnected =
        _castService.connectionState ==
            GoogleCastConnectState.connected;
    if (!isConnected) return false;
    final selected = _selectedDevice;
    if (selected == null) return false;
    return selected.friendlyName == device.friendlyName;
  }

  Future<void> _disconnectForReconnectIfNeeded(GoogleCastDevice target) async {
    final isConnected =
        _castService.connectionState ==
            GoogleCastConnectState.connected;
    if (!isConnected) return;
    final selected = _selectedDevice;
    if (selected == null) {
      await _ensureSessionDisconnected();
      return;
    }
    final sameDevice = selected.friendlyName == target.friendlyName;
    if (!sameDevice) {
      await _ensureSessionDisconnected();
      return;
    }
    if (_manualDisconnectRequested || !shouldKeepConnectionAlive) {
      await _ensureSessionDisconnected();
    }
  }

  void _startConnectionMonitor() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_monitorConnectionHealth()),
    );
  }

  void _stopConnectionMonitor() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
  }

  Future<void> _monitorConnectionHealth() async {
    if (_manualDisconnectRequested || !connectionLocked.value) return;
    final selectedDevice = _selectedDevice;
    if (selectedDevice == null) return;
    if (_castService.connectionState == GoogleCastConnectState.connected) return;

    progressMessage.value = 'Cast connection lost. Reconnecting...';
    final state = await _connectToDeviceWithRetry(selectedDevice);
    if (state != GoogleCastConnectState.connected) {
      _setError('Cast session dropped. Tap Media to reconnect.');
      connectionLocked.value = false;
      return;
    }

    if (_activeMedia != null && mediaQueue.isNotEmpty) {
      final index = currentMediaIndex.value.clamp(0, mediaQueue.length - 1);
      await castMediaAt(index);
      progressMessage.value = connectedDeviceName.value.isEmpty
          ? 'Reconnected. Casting resumed.'
          : 'Reconnected to ${connectedDeviceName.value}. Casting resumed.';
    }
  }

  String _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'image/jpeg';
  }
}

enum _GalleryPickMode { images, video, cancel }

class _PickedMediaEntry {
  const _PickedMediaEntry({
    required this.path,
    required this.name,
  });

  final String path;
  final String name;
}
