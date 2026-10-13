import 'package:dio/dio.dart';
import '../api.dart';
import 'api_service.dart';

class AiService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> interpretarProducto({
    required String texto,
    String modelo = 'glm-5.1',
    String? contexto,
  }) async {
    try {
      final data = {
        'texto': texto,
        'modelo': modelo,
      };
      if (contexto != null) {
        data['contexto'] = contexto;
      }
      final response = await _dio.post(
        '$BASE_URL/ai/interpretar-producto',
        data: FormData.fromMap(data),
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final raw = response.data['data'];
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e)).toList();
        } else {
          return [Map<String, dynamic>.from(raw)];
        }
      } else {
        throw Exception(response.data['error'] ?? 'Error al interpretar');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<Map<String, String>>> obtenerModelos() async {
    try {
      final response = await _dio.get('$BASE_URL/ai/modelos');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'] as List;
        return data.map((m) => Map<String, String>.from(m)).toList();
      }
      return _modelosDefault;
    } catch (e) {
      return _modelosDefault;
    }
  }

  List<Map<String, String>> get _modelosDefault => [
    {'id': 'glm-5.1', 'name': 'GLM-5.1 (Rápido)'},
    {'id': 'deepseek-v4-flash', 'name': 'DeepSeek V4 Flash'},
    {'id': 'deepseek-v4-pro', 'name': 'DeepSeek V4 Pro'},
    {'id': 'kimi-k2.6', 'name': 'Kimi K2.6'},
    {'id': 'qwen3.7-max', 'name': 'Qwen3.7 Max'},
  ];
}
