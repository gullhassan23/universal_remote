import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../services/tv_service_interface.dart';
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
  MediaCastController({TvConnectionController? connectionController})
    : _connectionController =
          connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;
  final Rx<MediaCastStatus> status = MediaCastStatus.idle.obs;
  final RxString errorMessage = ''.obs;
  final RxString progressMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_connectionController.castSession, (CastSessionUpdate update) {
      switch (update.state) {
        case CastSessionState.preparing:
        case CastSessionState.launching:
        case CastSessionState.displaying:
          progressMessage.value = update.message ?? '';
          break;
        case CastSessionState.failed:
          progressMessage.value = '';
          break;
        case CastSessionState.idle:
        case CastSessionState.stopped:
          progressMessage.value = '';
          break;
      }
    });
  }

  Future<void> pickAndCastImage() async {
    if (_connectionController.connectionState.value !=
        TvConnectionState.connected) {
      _setError('Connect to a TV before casting media.');
      return;
    }

    status.value = MediaCastStatus.picking;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      status.value = MediaCastStatus.idle;
      return;
    }

    final selected = result.files.first;
    final path = selected.path;
    if (path == null || path.isEmpty) {
      _setError('Unable to read selected image file.');
      return;
    }

    status.value = MediaCastStatus.casting;
    errorMessage.value = '';
    progressMessage.value = 'Preparing image for TV...';
    await _connectionController.startCastSession();

    final casted = await _connectionController.castMedia(
      CastMediaItem(
        type: CastMediaType.image,
        filePath: path,
        mimeType: _inferMimeType(path),
        title: selected.name,
        metadata: const <String, String>{'transport': 'local_http'},
      ),
    );

    if (!casted) {
      final serviceError = _connectionController.getLastServiceError();
      _setError(
        serviceError?.isNotEmpty == true
            ? serviceError!
            : 'Casting failed. Check TV connection and try again.',
      );
      return;
    }

    status.value = MediaCastStatus.success;
    Get.snackbar('Casting started', 'Image sent to your TV.');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (status.value == MediaCastStatus.success) {
      status.value = MediaCastStatus.idle;
    }
  }

  @override
  void onClose() {
    _connectionController.stopCasting();
    super.onClose();
  }

  void _setError(String message) {
    status.value = MediaCastStatus.error;
    errorMessage.value = message;
    Get.snackbar('Media cast', message);
  }

  String _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
