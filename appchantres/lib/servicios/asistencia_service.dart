import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

import '../servicios/api_service.dart';

class AsistenciaService {
  final Dio _dioCloud = ApiService().dio;
  final Dio _dioLocal = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  ));

  // Solicitar firma al servidor local
  Future<Map<String, dynamic>> solicitarFirmaLocal(int userId) async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String nonce = _generateNonce();
    final String baseUrl = await _getLocalServerUrl();
    
    try {
      final response = await _dioLocal.post(
        '$baseUrl/sellar',
        data: {
          'user_id': userId,
          'timestamp': timestamp,
          'nonce': nonce,
          'hwid': '', // Ahora el servidor local lo autodetecta si viene vacío
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'signature': data['signature'],
          'timestamp': timestamp,
          'nonce': nonce,
          'hwid': data['hwid'] ?? '', // Crucial: usar el HWID que el servidor local usó para firmar
        };
      }
      throw Exception('Error del servidor local: ${response.data['error']}');
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          throw Exception('No se pudo conectar al servidor local. Verifique que esté en la red de la empresa.');
        }
      }
      throw Exception('Error al conectar con servidor local: $e');
    }
  }

  // Enviar registro de asistencia a la nube con la firma
  Future<void> registrarAsistenciaNube(Map<String, dynamic> data) async {
    try {
      final response = await _dioCloud.post(
        '$BASE_URL/asistencias',
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode != 201) {
        throw Exception('Error al registrar en la nube: ${response.data['error']}');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw Exception(e.response?.data['error'] ?? 'Error desconocido en la nube');
      }
      throw Exception('Error de conexión con la nube: $e');
    }
  }

  // Registrar salida en la nube
  Future<void> registrarSalidaNube(Map<String, dynamic> data) async {
    try {
      final response = await _dioCloud.put(
        '$BASE_URL/asistencias/salida',
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al registrar salida: ${response.data['error']}');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw Exception(e.response?.data['error'] ?? 'Error desconocido al marcar salida');
      }
      throw Exception('Error de conexión con la nube: $e');
    }
  }

  // Verificar si ya marcó hoy o tiene entrada pendiente
  Future<List<dynamic>> obtenerAsistenciasPendientes(int userId) async {
    try {
      final response = await _dioCloud.get('$BASE_URL/asistencias/pendientes/$userId');
      if (response.statusCode == 200) {
        return response.data;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String> _getLocalServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final String ip = prefs.getString('local_attendance_ip') ?? '';
    return _formatUrl(ip);
  }

  String _generateNonce() {
    final rnd = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(Iterable.generate(
        16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Verificar conexión con el servidor local
  Future<Map<String, dynamic>> pingLocalServer({String? baseUrl}) async {
    try {
      final url = baseUrl != null ? _formatUrl(baseUrl) : await _getLocalServerUrl();
      // Usar una instancia limpia de Dio para evitar interceptores de token si el local no los requiere
      final response = await Dio().get('$url/ping').timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        return {
          'ok': response.data['ok'] ?? false,
          'hwid': response.data['hwid'] ?? '',
        };
      }
      return {'ok': false, 'error': 'Status ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': 'No se pudo conectar'};
    }
  }

  String _formatUrl(String ip) {
    if (ip.isEmpty) return LOCAL_SERVER_URL;
    if (!ip.startsWith('http')) {
      return 'http://$ip:5000';
    }
    return ip;
  }

  static String maskHwid(String hwid) {
    if (hwid.length < 8) return hwid;
    return '${hwid.substring(0, 4)}...${hwid.substring(hwid.length - 4)}';
  }
}
