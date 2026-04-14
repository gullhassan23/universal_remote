import 'dart:io';

class CastServeSession {
  const CastServeSession({
    required this.mediaUri,
    required this.viewerUri,
  });

  final Uri mediaUri;
  final Uri viewerUri;
}

class LocalMediaServer {
  HttpServer? _server;
  bool _isListening = false;
  String? _servedPath;
  String? _servedToken;
  String _servedMimeType = 'application/octet-stream';

  Future<CastServeSession?> serveFile({
    required String filePath,
    required String mimeType,
    String? preferredRemoteIp,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final bindAddress = await _resolveBindAddress(preferredRemoteIp);
    if (bindAddress == null) {
      return null;
    }

    _servedPath = file.path;
    _servedToken = DateTime.now().microsecondsSinceEpoch.toString();
    _servedMimeType = mimeType;
    _server ??= await HttpServer.bind(InternetAddress.anyIPv4, 0);
    if (!_isListening) {
      _isListening = true;
      _server!.listen((request) async {
        if (request.method != 'GET') {
          request.response.statusCode = HttpStatus.methodNotAllowed;
          await request.response.close();
          return;
        }

        final token = request.uri.queryParameters['token'];
        if (token == null || token != _servedToken) {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
          return;
        }

        if (_servedPath == null || _servedToken == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final path = request.uri.path;
        request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

        if (path == '/viewer') {
          request.response.headers.contentType = ContentType.html;
          request.response.write(_buildViewerHtml(token));
          await request.response.close();
          return;
        }

        if (path == '/media') {
          final servedFile = File(_servedPath!);
          if (!await servedFile.exists()) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }

          request.response.headers.contentType = ContentType.parse(_servedMimeType);
          await request.response.addStream(servedFile.openRead());
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
    }

    final mediaUri = Uri(
      scheme: 'http',
      host: bindAddress.address,
      port: _server!.port,
      path: '/media',
      queryParameters: {'token': _servedToken},
    );
    final viewerUri = Uri(
      scheme: 'http',
      host: bindAddress.address,
      port: _server!.port,
      path: '/viewer',
      queryParameters: {'token': _servedToken},
    );
    return CastServeSession(mediaUri: mediaUri, viewerUri: viewerUri);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _isListening = false;
    _servedPath = null;
    _servedToken = null;
    _servedMimeType = 'application/octet-stream';
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<InternetAddress?> _resolveBindAddress(String? preferredRemoteIp) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final preferredPrefix = _networkPrefix(preferredRemoteIp);

    if (preferredPrefix != null) {
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (_isPrivateAddress(addr) &&
              _networkPrefix(addr.address) == preferredPrefix) {
            return addr;
          }
        }
      }
    }

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (_isPrivateAddress(addr)) {
          return addr;
        }
      }
    }
    return null;
  }

  bool _isPrivateAddress(InternetAddress address) {
    final parts = address.address.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? -1;
    final b = int.tryParse(parts[1]) ?? -1;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  String? _networkPrefix(String? ip) {
    if (ip == null) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  String _buildViewerHtml(String token) {
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Media Cast</title>
  <style>
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #000;
    }
    #cast-image {
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
      background: #000;
    }
  </style>
</head>
<body>
  <img id="cast-image" src="/media?token=$token" alt="Cast image">
  <script>
    const root = document.documentElement;
    if (root.requestFullscreen) {
      root.requestFullscreen().catch(() => {});
    }
  </script>
</body>
</html>
''';
  }
}
