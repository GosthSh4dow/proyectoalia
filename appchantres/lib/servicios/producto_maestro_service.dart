import 'package:dio/dio.dart';
import '../api.dart';
import '../servicios/api_service.dart';
import '../models/producto_maestro.dart';

class ProductoMaestroService {
  final Dio _dio = ApiService().dio;

  Future<List<ProductoMaestro>> obtenerProductosMaestros() async {
    try {
      final response = await _dio.get('$BASE_URL/productos-maestros');

      if (response.statusCode == 200 && response.data['success'] == true) {
        List<dynamic> data = response.data['data'];
        return data.map((json) => ProductoMaestro.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar productos maestros');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<ProductoMaestro> obtenerProductoMaestro(int id) async {
    try {
      final response = await _dio.get('$BASE_URL/productos-maestros/$id');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ProductoMaestro.fromJson(response.data['data']);
      } else {
        throw Exception('Producto no encontrado');
      }
    } catch (e) {
      throw Exception('Error al obtener producto maestro: $e');
    }
  }
}
