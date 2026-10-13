import 'package:dio/dio.dart';
import '../api.dart';

import '../servicios/api_service.dart';

class ProveedorService {
  final Dio _dio = ApiService().dio;

  Future<List<dynamic>> obtenerProveedores() async {
    try {
      final response = await _dio.get('$BASE_URL/proveedores');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Error al cargar proveedores');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
