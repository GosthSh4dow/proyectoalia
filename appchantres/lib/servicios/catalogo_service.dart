import 'dart:convert';
import 'package:dio/dio.dart';
import '../api.dart';
import '../servicios/api_service.dart';
import '../models/catalogo_model.dart';

class CatalogoService {
  final Dio _dio = ApiService().dio;

  // Crear información del catálogo
  Future<CatalogoInfo> crearCatalogo(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/catalogo-info',
        data: FormData.fromMap(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          return CatalogoInfo.fromJson(response.data);
        } else if (response.data is List && response.data.isNotEmpty) {
          return CatalogoInfo.fromJson(response.data[0]);
        }
        return CatalogoInfo();
      }
      throw Exception('Error al crear información del catálogo: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error al crear catálogo: $e');
    }
  }

  // Obtener la información del catálogo (tomamos la primera activa o la más reciente)
  Future<CatalogoInfo> obtenerCatalogo() async {
    try {
      final response = await _dio.get('$BASE_URL/catalogo-info');
      if (response.statusCode == 200) {
        List<dynamic> list = response.data;
        if (list.isNotEmpty) {
          return CatalogoInfo.fromJson(list[0]);
        }
        return CatalogoInfo();
      }
      throw Exception('Error al cargar información del catálogo');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar la información del catálogo
  Future<void> actualizarCatalogo(int id, Map<String, dynamic> data) async {
    try {
      // Usamos FormData si hay archivos, pero para campos de texto simples:
      final response = await _dio.put(
        '$BASE_URL/catalogo-info/$id',
        data: FormData.fromMap(data),
      );
      if (response.statusCode != 200) {
        throw Exception('Error al actualizar catálogo');
      }
    } catch (e) {
      throw Exception('Error al actualizar catálogo: $e');
    }
  }

  // Subir imagen (Banner o Logo)
  Future<void> subirImagen(int id, String tipo, dynamic file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      String endpoint = tipo == 'banner' ? 'banner/imagenes' : 'logos';
      String fileName = file.path.split(RegExp(r'[/\\]')).last;
      
      FormData formData = FormData.fromMap({
        "imagen": await MultipartFile.fromFile(file.path, filename: fileName),
        "titulo": tipo == 'banner' ? "Imagen del Banner" : "Logo",
      });

      final response = await _dio.post(
        '$BASE_URL/catalogo-info/$id/$endpoint',
        data: formData,
        onSendProgress: onProgress,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al subir imagen: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
        print("Error details: ${e.response?.data}");
      }
      throw Exception('Error al subir imagen: $e');
    }
  }

  // Eliminar imagen
  Future<void> eliminarImagen(int id, String tipo, String imagenId) async {
    try {
      String endpoint = tipo == 'banner' ? 'banner/imagenes' : 'logos';
      final response = await _dio.delete('$BASE_URL/catalogo-info/$id/$endpoint/$imagenId');
      if (response.statusCode != 200) {
        throw Exception('Error al eliminar imagen');
      }
    } catch (e) {
      throw Exception('Error al eliminar imagen: $e');
    }
  }

  // Eliminar imagen principal
  Future<void> eliminarImagenPrincipal(int id, String tipo) async {
    try {
      String endpoint = tipo == 'banner' ? 'banner' : 'logo';
      final response = await _dio.delete('$BASE_URL/catalogo-info/$id/$endpoint');
      if (response.statusCode != 200) {
        throw Exception('Error al eliminar imagen principal');
      }
    } catch (e) {
      throw Exception('Error al eliminar imagen principal: $e');
    }
  }
}
