import 'package:dio/dio.dart';
import '../api.dart';
import '../servicios/api_service.dart';
import '../models/sucursal.dart';

class SucursalService {
  final Dio _dio = ApiService().dio;

  Future<List<Sucursal>> obtenerSucursales() async {
    try {
      final response = await _dio.get('$BASE_URL/sucursales');

      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => Sucursal.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar sucursales');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
