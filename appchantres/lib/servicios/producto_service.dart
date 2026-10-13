import 'package:dio/dio.dart';
import '../api.dart'; // Importa BASE_URL
import '../servicios/api_service.dart';
import '../models/producto.dart';

class ProductoService {
  final Dio _dio = ApiService().dio;

  Future<List<Producto>> obtenerProductos({int? idSucursal}) async {
    // Compat: página 1 por defecto (antes traía 5960 de golpe).
    return obtenerProductosPaginados(idSucursal: idSucursal, page: 1, limit: 100);
  }

  /// Catálogo paginado server-side (usa ?page=&limit=&id_sucursal=&search=).
  Future<List<Producto>> obtenerProductosPaginados({
    int? idSucursal,
    int page = 1,
    int limit = 100,
    String? search,
  }) async {
    try {
      final qp = <String, dynamic>{'page': page, 'limit': limit};
      if (idSucursal != null) qp['id_sucursal'] = idSucursal;
      if (search != null && search.trim().isNotEmpty) {
        qp['search'] = search.trim();
      }
      final response = await _dio.get('$BASE_URL/productos', queryParameters: qp);

      if (response.statusCode == 200) {
        final d = response.data;
        final List<dynamic> data = d is List
            ? d
            : (d is Map && d['data'] is List ? d['data'] as List : []);
        return data.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar productos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Búsqueda server-side para no filtrar miles en RAM.
  Future<List<Producto>> buscarProductosServer({
    int? idSucursal,
    required String query,
    int limit = 50,
  }) async {
    return obtenerProductosPaginados(
        idSucursal: idSucursal, page: 1, limit: limit, search: query);
  }

  Future<Producto?> buscarProductoPorCodigo(String codigo) async {
    try {
      // Intentar buscar por endpoint de códigos alternativos (prioritario)
      // Este endpoint busca tanto en códigos alternativos como en código de barras principal
      final response = await _dio.get('$BASE_URL/codigos/buscar/$codigo');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return Producto.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      // Si falla, podr?amo intentar el endpoint antiguo como fallback, 
      // pero el nuevo deberí­a cubrir todo.
      return null;
    }
  }

  /// Verifica si un código ya pertenece a otro producto distinto al indicado.
  /// Devuelve el nombre del producto que ya usa el código, o null si está libre.
  Future<String?> verificarCodigoEnOtroProducto(
    String codigo, {
    int? exceptoProductoId,
  }) async {
    try {
      final producto = await buscarProductoPorCodigo(codigo);
      if (producto == null) return null;
      if (exceptoProductoId != null && producto.id == exceptoProductoId) {
        return null;
      }
      return producto.nombre;
    } catch (_) {
      return null;
    }
  }

  /// Crea producto con distribución multi-sucursal.
  /// Acepta un FormData ya construido correctamente por el caller.
  Future<Map<String, dynamic>> crearProductoConDistribucion(
    FormData formData, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/productos/distribucion',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception('Error al crear producto');
      }
    } catch (e) {
      throw Exception('Error al crear producto: $e');
    }
  }
}
