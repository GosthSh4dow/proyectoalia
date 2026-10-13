import 'package:dio/dio.dart';
import '../api.dart';

import '../servicios/api_service.dart';

class CategoriaService {
  final Dio _dio = ApiService().dio;

  Future<List<dynamic>> obtenerCategorias() async {
    try {
      final response = await _dio.get('$BASE_URL/categorias');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Error al cargar categorías');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
