import 'package:flutter/foundation.dart';

// Fallback remoto (producción)
const String _fallbackHost = '167.86.105.53';
const int _apiPort = 3009;
const int _localSelladoPort = 5000;

// Permite override en tiempo de compilación:
// --dart-define=API_HOST=192.168.1.5 --dart-define=API_PORT=3009 --dart-define=API_HTTPS=true
const String _envHost = String.fromEnvironment('API_HOST', defaultValue: '');
const int _envPort = int.fromEnvironment('API_PORT', defaultValue: 0);
const bool _envHttps = bool.fromEnvironment('API_HTTPS', defaultValue: false);

/// Detecta host LAN si la app corre en Web y window.hostname es 192.168.x.x o 10.0.x.x
/// Usa Uri.base.host (equivalente a window.location.hostname en web).
String _detectHost() {
  if (_envHost.isNotEmpty) {
    debugPrint('[api] _detectHost: usando API_HOST=$_envHost (dart-define)');
    return _envHost;
  }
  if (kIsWeb) {
    try {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        // Si hostname contiene red local, usa esa IP (ej: 192.168.1.3)
        if (host.contains('192.168') || host.contains('10.0')) {
          debugPrint('[api] _detectHost: usando host LAN detectado $host');
          return host;
        }
        // Opcional: si es localhost en web, igual usar fallback remoto
        debugPrint('[api] _detectHost: host web=$host no es LAN, usa fallback');
      }
    } catch (e) {
      debugPrint('[api] _detectHost error: $e');
    }
  }
  // Local debug: Android emulador 10.0.2.2, desktop/iOS 127.0.0.1, físico usa --dart-define=API_HOST=192.168.1.X
  if (kDebugMode && !kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('[api] _detectHost: Android debug -> 10.0.2.2 (emulador)');
      return '10.0.2.2';
    }
    debugPrint('[api] _detectHost: debug desktop/iOS -> 127.0.0.1');
    return '127.0.0.1';
  }
  return _fallbackHost;
}

String? _cachedHost;
String get _effectiveHost {
  _cachedHost ??= _detectHost();
  return _cachedHost!;
}

/// Puerto efectivo (define o 3009) y esquema (https solo con API_HTTPS=true).
int get API_PORT => _envPort > 0 ? _envPort : _apiPort;
String get API_SCHEME => _envHttps ? 'https' : 'http';

/// URLs base dinámicas: si window.hostname contiene 192.168 o 10.0 usa esa IP, si no fallback.
String get BASE_URL => '$API_SCHEME://$_effectiveHost:$API_PORT/api';
String get API_BASE_URL => '$API_SCHEME://$_effectiveHost:$API_PORT/api';

// Mantener compatibilidad: algunos archivos importan LOCAL_SERVER_URL constante.
String get LOCAL_SERVER_URL => 'http://$_effectiveHost:$_localSelladoPort';

String getApiUrl(String endpoint) => '$BASE_URL/$endpoint';

String getImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;

  // Normalize path (convert backslashes to forward slashes and remove leading slash)
  String normalizedPath = path.replaceAll('\\', '/');
  while (normalizedPath.startsWith('/')) {
    normalizedPath = normalizedPath.substring(1);
  }

  // Base URL for uploads (ensure it ends with /)
  String baseUrl = API_BASE_URL;
  if (!baseUrl.endsWith('/')) {
    baseUrl += '/';
  }

  return baseUrl + normalizedPath;
}
