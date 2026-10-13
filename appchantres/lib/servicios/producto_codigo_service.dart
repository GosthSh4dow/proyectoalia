import 'package:dio/dio.dart';
import '../api.dart';
import '../models/producto_codigo.dart';

import '../servicios/api_service.dart';

class ProductoCodigoService {
  final Dio _dio = ApiService().dio;

  Future<List<ProductoCodigo>> obtenerCodigos(int productoId) async {
    try {
      final response = await _dio.get('$BASE_URL/codigos/producto/$productoId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        List<dynamic> data = response.data['data'];
        return data.map((json) => ProductoCodigo.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar códigos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<ProductoCodigo> crearCodigo(int productoId, String codigo, String tipo, bool esPrincipal) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/codigos/producto/$productoId',
        data: {
          'codigo': codigo,
          'tipo': tipo,
          'es_principal': esPrincipal
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return ProductoCodigo.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Error al crear código');
      }
    } catch (e) {
      throw Exception('Error al crear código: $e');
    }
  }

  Future<void> eliminarCodigo(int id) async {
    try {
      final response = await _dio.delete('$BASE_URL/codigos/$id');
      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Error al eliminar código');
      }
    } catch (e) {
      throw Exception('Error al eliminar código: $e');
    }
  }
}
