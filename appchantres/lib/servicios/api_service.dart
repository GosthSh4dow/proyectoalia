import 'package:dio/dio.dart';
import '../api.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final Dio dio = Dio();
  String? _token;
  String? _refreshToken;
  
  // Callback para cuando se necesita cerrar sesión (ej. refresh token falló)
  Function? onLogoutRequired;
  // Callback para cuando el token se actualiza (ej. tras renovación exitosa)
  Function(String newToken)? onTokenUpdated;

  ApiService._internal() {
    _setupInterceptors();
  }

  /// Aumenta los timeouts para subida de archivos grandes
  void setUploadTimeout() {
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.sendTimeout = const Duration(seconds: 120);
    dio.options.receiveTimeout = const Duration(seconds: 120);
  }

  /// Restaura los timeouts por defecto
  void resetTimeout() {
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.sendTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  void updateTokens(String? token, String? refreshToken) {
    _token = token;
    _refreshToken = refreshToken;
    if (token != null) {
      dio.options.headers["Authorization"] = "Bearer $token";
    } else {
      dio.options.headers.remove("Authorization");
    }
  }

  void _setupInterceptors() {
    dio.options.baseUrl = BASE_URL;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $_token";
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Detectar 401 y asegurar que tenemos un refresh token y que no estamos ya solicitando refresco
        if (e.response?.statusCode == 401 && 
            _refreshToken != null && 
            _refreshToken!.isNotEmpty &&
            !e.requestOptions.path.contains('/auth/refresh-token')) {
          
          print("Token expirado o inválido (401). Intentando renovación automática...");
          
          try {
            final newToken = await _renewToken();
            if (newToken != null) {
              // Reintentar la solicitud original con el nuevo token
              e.requestOptions.headers["Authorization"] = "Bearer $newToken";
              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            }
          } catch (error) {
            print("Error durante la renovación automática: $error");
          }
          
          // Si llegamos aquí, la renovación falló
          if (onLogoutRequired != null) {
            onLogoutRequired!();
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<String?> _renewToken() async {
    try {
      // Usar una instancia de Dio limpia para la renovación
      final response = await Dio().post(
        '$BASE_URL/auth/refresh-token',
        data: {'refreshToken': _refreshToken},
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        final newToken = response.data['token'];
        _token = newToken;
        
        if (onTokenUpdated != null) {
          onTokenUpdated!(newToken);
        }
        
        return newToken;
      }
    } catch (e) {
      print('Error fatal al renovar token: $e');
    }
    return null;
  }
}
