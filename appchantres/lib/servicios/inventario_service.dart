import 'package:dio/dio.dart';
import 'api_service.dart';

class InventarioService {
  final Dio _dio = ApiService().dio;

  // Fase 1: Marcar pedido como recibido
  Future<Map<String, dynamic>> recibirPedido(int pedidoId) async {
    try {
      final response = await _dio.post('/api/inventario/recibir/$pedidoId');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Fase 3: Commit masivo de distribución
  Future<Map<String, dynamic>> commitDistribucionMasiva(List<Map<String, dynamic>> items) async {
    try {
      final response = await _dio.post('/api/inventario/commit', data: items);
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(dynamic e) {
    if (e is DioException) {
      return e.response?.data['error'] ?? 'Error de conexión con el servidor';
    }
    return e.toString();
  }
}
