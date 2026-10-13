import 'dart:io';
import 'package:dio/dio.dart';
import '../api.dart';
import '../models/anuncio_model.dart';

import '../servicios/api_service.dart';

class AnuncioService {
  final Dio _dio = ApiService().dio;

  Future<List<Anuncio>> obtenerAnuncios() async {
    try {
      final response = await _dio.get('$BASE_URL/anuncios');
      if (response.statusCode == 200) {
        List<dynamic> list = response.data;
        return list.map((json) => Anuncio.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error al cargar anuncios: $e');
    }
  }

  Future<void> crearAnuncio(Anuncio anuncio, File? imagen, {int? creatorId, void Function(int sent, int total)? onProgress}) async {
    try {
      Map<String, dynamic> data = anuncio.toJson(creatorId: creatorId);
      if (imagen != null) {
        data['imagen'] = await MultipartFile.fromFile(
          imagen.path,
          filename: imagen.path.split('/').last,
        );
      }
      
      final response = await _dio.post(
        '$BASE_URL/anuncios',
        data: FormData.fromMap(data),
        onSendProgress: onProgress,
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al crear anuncio: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al crear anuncio: $e');
    }
  }

  Future<void> actualizarAnuncio(int id, Anuncio anuncio, File? imagen, {int? creatorId, void Function(int sent, int total)? onProgress}) async {
    try {
      Map<String, dynamic> data = anuncio.toJson(creatorId: creatorId);
      if (imagen != null) {
        data['imagen'] = await MultipartFile.fromFile(
          imagen.path,
          filename: imagen.path.split('/').last,
        );
      }
      
      final response = await _dio.put(
        '$BASE_URL/anuncios/$id',
        data: FormData.fromMap(data),
        onSendProgress: onProgress,
      );
      
      if (response.statusCode != 200) {
        throw Exception('Error al actualizar anuncio');
      }
    } catch (e) {
      throw Exception('Error al actualizar anuncio: $e');
    }
  }

  Future<void> eliminarAnuncio(int id) async {
    try {
      final response = await _dio.delete('$BASE_URL/anuncios/$id');
      if (response.statusCode != 200) {
        throw Exception('Error al eliminar anuncio');
      }
    } catch (e) {
      throw Exception('Error al eliminar anuncio: $e');
    }
  }
}
