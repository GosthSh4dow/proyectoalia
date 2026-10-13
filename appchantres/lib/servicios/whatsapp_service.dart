import 'package:dio/dio.dart';
import '../api.dart';
import 'api_service.dart';
/// Llama al backend (POST /api/whatsapp/send, requiere login).
/// El backend usa la Cloud API de Meta; la APK nunca maneja el token de Meta.
class WhatsappService {
  final Dio _dio = ApiService().dio;

  /// Envía un mensaje de texto. [para] en formato internacional sin '+' (ej: 59170000000).
  /// Retorna el id del mensaje en Meta, o null si no vino id.
  Future<String?> enviarMensaje({required String para, required String mensaje}) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/whatsapp/send',
        data: {'para': para, 'mensaje': mensaje},
      );
      if (response.statusCode == 200) {
        return response.data['id']?.toString();
      }
      return null;
    } catch (e) {
      throw Exception('Error al enviar WhatsApp: $e');
    }
  }

  /// Envía una imagen por URL pública (o ruta /uploads/... del backend). [caption] opcional.
  Future<String?> enviarImagen({required String para, required String imagen, String? caption}) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/whatsapp/send-imagen',
        data: {'para': para, 'imagen': imagen, if (caption != null) 'caption': caption},
      );
      if (response.statusCode == 200) {
        return response.data['id']?.toString();
      }
      return null;
    } catch (e) {
      throw Exception('Error al enviar imagen por WhatsApp: $e');
    }
  }

  /// Envía un documento/PDF por URL pública (o ruta /uploads/... del backend).
  Future<String?> enviarDocumento({required String para, required String documento, String? filename, String? caption}) async {
    try {
      final response = await _dio.post(
        '$BASE_URL/whatsapp/send-documento',
        data: {
          'para': para,
          'documento': documento,
          if (filename != null) 'filename': filename,
          if (caption != null) 'caption': caption,
        },
      );
      if (response.statusCode == 200) {
        return response.data['id']?.toString();
      }
      return null;
    } catch (e) {
      throw Exception('Error al enviar documento por WhatsApp: $e');
    }
  }

  /// QR vigente del negocio (el que se envía al aprobar). Null si no hay configurado.
  Future<String?> negocioQrUrl() async {
    try {
      final response = await _dio.get('$BASE_URL/whatsapp/negocio-qr');
      if (response.statusCode == 200) {
        return response.data['url']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cambia el QR fijo del negocio subiendo una imagen (jpg/png/webp).
  /// Retorna la URL pública nueva.
  Future<String?> subirQr(String imagePath) async {
    try {
      final form = FormData.fromMap({
        'qr': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
      });
      final response = await _dio.post('$BASE_URL/whatsapp/negocio-qr', data: form);
      if (response.statusCode == 200) {
        return response.data['url']?.toString();
      }
      return null;
    } catch (e) {
      throw Exception('Error al subir QR: $e');
    }
  }
}
