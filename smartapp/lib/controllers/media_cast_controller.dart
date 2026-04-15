import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart';
import 'package:flutter_chrome_cast/session.dart';
import 'package:get/get.dart';

import 'tv_connection_controller.dart';

enum MediaCastStatus {
  idle,
  selectingTarget,
  picking,
  casting,
  success,
  error,
}

class MediaCastController extends GetxController {
  MediaCastController({TvConnectionController? connectionController});
  final Rx<MediaCastStatus> status = MediaCastStatus.idle.obs;
  final RxString errorMessage = ''.obs;
  final RxString progressMessage = ''.obs;
  bool _isCastContextInitialized = false;
  HttpServer? _mediaServer;
  File? _servedMediaFile;
  String? _servedMimeType;

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> pickAndCastMedia() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _setError('Media casting is currently supported on Android and iOS only.');
      return;
    }

    try {
      errorMessage.value = '';
      await _ensureCastContext();

      status.value = MediaCastStatus.picking;
      progressMessage.value = 'Pick a photo or video to cast...';
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'mp4',
          'mov',
          'm4v',
          'webm',
        ],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        _resetToIdle();
        return;
      }

      final selected = result.files.first;
      final path = selected.path;
      if (path == null || path.isEmpty) {
        _setError('Unable to read selected media file.');
        return;
      }

      final mimeType = _inferMimeType(path);
      if (!(mimeType.startsWith('image/') || mimeType.startsWith('video/'))) {
        _setError('Please select a supported image or video file.');
        return;
      }

      status.value = MediaCastStatus.selectingTarget;
      progressMessage.value = 'Searching for cast devices...';
      GoogleCastDiscoveryManager.instance.startDiscovery();

      final devices = await GoogleCastDiscoveryManager.instance.devicesStream
          .firstWhere((List<GoogleCastDevice> list) => list.isNotEmpty)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => <GoogleCastDevice>[],
          );
      if (devices.isEmpty) {
        _setError('No cast devices found on this Wi-Fi network.');
        return;
      }

      final selectedDevice = await _selectDevice(devices);
      if (selectedDevice == null) {
        _resetToIdle();
        return;
      }

      progressMessage.value = 'Connecting to ${selectedDevice.friendlyName}...';
      await GoogleCastSessionManager.instance.startSessionWithDevice(
        selectedDevice,
      );

      final connectionState = GoogleCastSessionManager.instance.connectionState;
      if (connectionState != GoogleCastConnectState.connected) {
        _setError('Could not connect to ${selectedDevice.friendlyName}.');
        return;
      }

      final mediaUri = await _serveMediaFile(
        filePath: path,
        mimeType: mimeType,
      );
      if (mediaUri == null) {
        _setError('Failed to prepare media for casting on local network.');
        return;
      }

      status.value = MediaCastStatus.casting;
      progressMessage.value = 'Casting media to ${selectedDevice.friendlyName}...';
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformationIOS(
          contentId: selected.name.isEmpty ? path.split('/').last : selected.name,
          streamType: CastMediaStreamType.buffered,
          contentUrl: mediaUri,
          contentType: mimeType,
          metadata: GoogleCastMovieMediaMetadata(
            title: selected.name.isEmpty ? 'Media file' : selected.name,
          ),
        ),
        autoPlay: true,
        playPosition: Duration.zero,
        playbackRate: 1.0,
      );

      status.value = MediaCastStatus.success;
      progressMessage.value = '';
      Get.snackbar(
        'Casting started',
        'Playing on ${selectedDevice.friendlyName}.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _resetToIdle();
    } catch (error, stackTrace) {
      debugPrint('Media cast error: $error');
      debugPrint('$stackTrace');
      _setError('Casting failed. Please try again.');
    }
  }

  Future<void> pickAndCastImage() async {
    await pickAndCastMedia();
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

  Future<Uri?> _serveMediaFile({
    required String filePath,
    required String mimeType,
  }) async {
    await _stopMediaServer();
    final mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      return null;
    }

    final bindAddress = await _resolvePrivateAddress();
    if (bindAddress == null) return null;

    _servedMediaFile = mediaFile;
    _servedMimeType = mimeType;
    _mediaServer = await HttpServer.bind(bindAddress, 0);
    unawaited(_mediaServer!.forEach(_handleMediaRequest));

    return Uri(
      scheme: 'http',
      host: bindAddress.address,
      port: _mediaServer!.port,
      path: '/media',
    );
  }

  @override
  void onClose() {
    unawaited(_stopMediaServer());
    GoogleCastDiscoveryManager.instance.stopDiscovery();
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

  Future<void> _handleMediaRequest(HttpRequest request) async {
    final mediaFile = _servedMediaFile;
    final mimeType = _servedMimeType;
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
    _servedMediaFile = null;
    _servedMimeType = null;
    final server = _mediaServer;
    _mediaServer = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<InternetAddress?> _resolvePrivateAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
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
