import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart';
import 'package:flutter_chrome_cast/session.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

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
  MediaCastController({TvConnectionController? connectionController});
  final ImagePicker _imagePicker = ImagePicker();
  final Rx<MediaCastStatus> status = MediaCastStatus.idle.obs;
  final RxString errorMessage = ''.obs;
  final RxString progressMessage = ''.obs;
  final RxString connectedDeviceName = ''.obs;
  final RxBool isConnecting = false.obs;
  final RxBool connectionLocked = false.obs;
  final RxList<CastMediaItem> mediaQueue = <CastMediaItem>[].obs;
  final RxInt currentMediaIndex = 0.obs;
  final RxInt mediaVersion = 0.obs;
  bool _isCastContextInitialized = false;
  bool _isDiscovering = false;
  HttpServer? _mediaServer;
  CastMediaItem? _activeMedia;
  GoogleCastDevice? _selectedDevice;
  bool _manualDisconnectRequested = false;

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
      GoogleCastSessionManager.instance.connectionState ==
          GoogleCastConnectState.connected;
  bool get shouldKeepConnectionAlive =>
      connectionLocked.value && !_manualDisconnectRequested;

  CastMediaItem? get currentMedia {
    if (mediaQueue.isEmpty) return null;
    final index = currentMediaIndex.value.clamp(0, mediaQueue.length - 1);
    return mediaQueue[index];
  }

  Future<void> pickAndCastMedia() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _setError('Media casting is currently supported on Android and iOS only.');
      return;
    }

    try {
      errorMessage.value = '';
      await _ensureCastContext();

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

    await GoogleCastRemoteMediaClient.instance.loadMedia(
      GoogleCastMediaInformationIOS(
        contentId: mediaUri.toString(),
        streamType: CastMediaStreamType.buffered,
        contentUrl: mediaUri,
        contentType: media.mimeType,
        metadata: GoogleCastMovieMediaMetadata(title: media.name),
      ),
      autoPlay: true,
      playPosition: Duration.zero,
      playbackRate: 1.0,
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

  Future<void> _ensureCastContext() async {
    if (_isCastContextInitialized) {
      return;
    }

    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    if (Platform.isIOS) {
      final options = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
      );
      GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    } else if (Platform.isAndroid) {
      final options = GoogleCastOptionsAndroid(appId: appId);
      GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    }

    _isCastContextInitialized = true;
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

    await _ensureMediaServer();
    final server = _mediaServer;
    if (server == null) return null;

    final cacheBust = DateTime.now().millisecondsSinceEpoch.toString();
    return Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      path: '/media',
      queryParameters: <String, String>{'v': cacheBust},
    );
  }

  @override
  void onClose() {
    unawaited(_stopMediaServer());
    _stopDiscovery();
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
    _startDiscovery();
    _manualDisconnectRequested = false;

    try {
      final discoveryTimeout = Platform.isIOS
          ? const Duration(seconds: 25)
          : const Duration(seconds: 15);
      final devices = await GoogleCastDiscoveryManager.instance.devicesStream
          .firstWhere((List<GoogleCastDevice> list) => list.isNotEmpty)
          .timeout(
            discoveryTimeout,
            onTimeout: () => <GoogleCastDevice>[],
          );
      if (devices.isEmpty) {
        _setError(
          Platform.isIOS
              ? 'No cast devices found. On iPhone, allow Local Network access for this app in iOS Settings, then retry on the same Wi-Fi.'
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
      return true;
    } finally {
      _stopDiscovery();
      isConnecting.value = false;
    }
  }

  void _startDiscovery() {
    if (_isDiscovering) return;
    GoogleCastDiscoveryManager.instance.startDiscovery();
    _isDiscovering = true;
  }

  void _stopDiscovery() {
    if (!_isDiscovering) return;
    GoogleCastDiscoveryManager.instance.stopDiscovery();
    _isDiscovering = false;
  }

  Future<void> _ensureSessionDisconnected() async {
    if (GoogleCastSessionManager.instance.connectionState ==
        GoogleCastConnectState.connected) {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
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
    var lastState = GoogleCastSessionManager.instance.connectionState;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await _disconnectForReconnectIfNeeded(selectedDevice);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await GoogleCastSessionManager.instance.startSessionWithDevice(
        selectedDevice,
      );

      progressMessage.value = attempt == 1
          ? 'Waiting for ${selectedDevice.friendlyName} to accept cast session...'
          : 'Retrying connection to ${selectedDevice.friendlyName}...';
      lastState = await _waitForConnectedSession();
      if (lastState == GoogleCastConnectState.connected) {
        return lastState;
      }
    }
    return lastState;
  }

  bool _canReuseConnectedSession(GoogleCastDevice device) {
    final isConnected =
        GoogleCastSessionManager.instance.connectionState ==
            GoogleCastConnectState.connected;
    if (!isConnected) return false;
    final selected = _selectedDevice;
    if (selected == null) return false;
    return selected.friendlyName == device.friendlyName;
  }

  Future<void> _disconnectForReconnectIfNeeded(GoogleCastDevice target) async {
    final isConnected =
        GoogleCastSessionManager.instance.connectionState ==
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

  Future<GoogleCastConnectState> _waitForConnectedSession() async {
    final endAt = DateTime.now().add(const Duration(seconds: 20));
    var state = GoogleCastSessionManager.instance.connectionState;
    while (DateTime.now().isBefore(endAt) &&
        state != GoogleCastConnectState.connected) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      state = GoogleCastSessionManager.instance.connectionState;
    }
    return state;
  }

  Future<void> _handleMediaRequest(HttpRequest request) async {
    final media = _activeMedia;
    final mediaPath = media?.path;
    final mimeType = media?.mimeType;
    final mediaFile = mediaPath == null ? null : File(mediaPath);
    if (mediaFile == null || mimeType == null || request.uri.path != '/media') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final fileLength = await mediaFile.length();
      request.response.headers.set(HttpHeaders.contentTypeHeader, mimeType);
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.startsWith('bytes=')) {
        final parts = range.replaceFirst('bytes=', '').split('-');
        final start = int.tryParse(parts.first) ?? 0;
        final end = parts.length > 1 && parts[1].isNotEmpty
            ? int.tryParse(parts[1]) ?? fileLength - 1
            : fileLength - 1;

        if (start < 0 || end >= fileLength || start > end) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$fileLength');
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$fileLength',
        );
        request.response.contentLength = end - start + 1;
        await request.response.addStream(mediaFile.openRead(start, end + 1));
        await request.response.close();
        return;
      }

      request.response.contentLength = fileLength;
      await request.response.addStream(mediaFile.openRead());
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _stopMediaServer() async {
    final server = _mediaServer;
    _mediaServer = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> _ensureMediaServer() async {
    if (_mediaServer != null) return;
    final bindAddress = await _resolvePrivateAddress();
    if (bindAddress == null) return;
    _mediaServer = await HttpServer.bind(bindAddress, 0);
    unawaited(_mediaServer!.forEach(_handleMediaRequest));
  }

  Future<InternetAddress?> _resolvePrivateAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final sortedInterfaces = List<NetworkInterface>.from(interfaces)
      ..sort((a, b) {
        final aScore = _networkInterfacePriority(a.name);
        final bScore = _networkInterfacePriority(b.name);
        return bScore.compareTo(aScore);
      });
    for (final interface in sortedInterfaces) {
      for (final address in interface.addresses) {
        if (_isPrivate(address)) {
          return address;
        }
      }
    }
    return null;
  }

  bool _isPrivate(InternetAddress address) {
    final parts = address.address.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? -1;
    final b = int.tryParse(parts[1]) ?? -1;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  int _networkInterfacePriority(String interfaceName) {
    final name = interfaceName.toLowerCase();
    if (name.contains('wlan') || name.contains('wifi') || name == 'en0') {
      return 3;
    }
    if (name.contains('eth') || name.startsWith('en')) {
      return 2;
    }
    return 1;
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
