import 'package:dio/dio.dart';
import '../api.dart';

import '../servicios/api_service.dart';

class SueldosService {
  final Dio _dio = ApiService().dio;

  // Obtener lista de empleados (usuarios)
  Future<List<dynamic>> obtenerEmpleados() async {
    try {
      final response = await _dio.get('$BASE_URL/usuarios');
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Error al cargar empleados');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener asistencias de un empleado
  Future<List<dynamic>> obtenerAsistencias(String empleadoId, {String? fechaPago}) async {
    try {
      final response = await _dio.get('$BASE_URL/asistencias/$empleadoId');
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        List<dynamic> data = [];

        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') && responseData['data'] is List) {
            data = responseData['data'];
          } else if (responseData.containsKey('asistencias') && responseData['asistencias'] is List) {
            data = responseData['asistencias'];
          }
        }

        if (fechaPago != null) {
          data = data.where((item) =>
              DateTime.parse(item['fecha']).isAfter(DateTime.parse(fechaPago))
          ).toList();
        }
        return data;
      }
      throw Exception('Error al cargar asistencias');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener boletas de pago
  Future<List<dynamic>> obtenerBoletas() async {
    try {
      final response = await _dio.get('$BASE_URL/boletas');
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Error al cargar boletas');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear una nueva boleta
  Future<void> crearBoleta(Map<String, dynamic> boletaData) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/boletas',
        data: boletaData,
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al generar boleta');
      }
    } catch (e) {
      throw Exception('Error al crear boleta: $e');
    }
  }

  // Actualizar asistencia
  Future<void> actualizarAsistencia(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '$BASE_URL/asistencias/$id',
        data: data,
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200) {
        throw Exception('Error al actualizar asistencia');
      }
    } catch (e) {
      throw Exception('Error al actualizar asistencia: $e');
    }
  }

  // Eliminar asistencia
  Future<void> eliminarAsistencia(String id) async {
    try {
      final response = await _dio.delete('$BASE_URL/asistencias/$id');
      if (response.statusCode != 200) {
        throw Exception('Error al eliminar asistencia');
      }
    } catch (e) {
      throw Exception('Error al eliminar asistencia: $e');
    }
  }
}
