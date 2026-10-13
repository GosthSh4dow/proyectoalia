import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import '../servicios/api_service.dart';

class UploadResult {
  final bool success;
  final dynamic data;
  final String? error;

  const UploadResult({required this.success, this.data, this.error});
}

class UploadService {
  static final Dio _dio = ApiService().dio;

  /// Sube un FormData al endpoint indicado con retry exponencial.
  static Future<UploadResult> uploadProduct({
    required String endpoint,
    required FormData formData,
    void Function(double progress, String phase)? onProgress,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          onProgress?.call(0.0, 'Reintentando ($attempt/$maxRetries)...');
        }

        final response = await _dio.post(
          endpoint,
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = sent / total;
              onProgress?.call(progress, 'Subiendo producto...');
            }
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return UploadResult(success: true, data: response.data);
        } else {
          return UploadResult(
            success: false,
            error: 'Error del servidor: ${response.statusCode}',
          );
        }
      } on DioException catch (e) {
        final isLastAttempt = attempt == maxRetries;
        if (isLastAttempt) {
          String msg = 'Error de conexión';
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            msg = 'Tiempo de espera agotado';
          } else if (e.type == DioExceptionType.connectionError) {
            msg = 'Sin conexión a internet';
          } else if (e.response?.statusCode == 413) {
            msg = 'Imagen demasiado grande';
          }
          return UploadResult(success: false, error: msg);
        }

        final delay = pow(2, attempt).toInt();
        onProgress?.call(0.0, 'Reintentando en ${delay}s...');
        await Future.delayed(Duration(seconds: delay));
      } catch (e) {
        return UploadResult(success: false, error: 'Error inesperado: $e');
      }
    }

    return const UploadResult(success: false, error: 'Error desconocido');
  }

  /// Sube producto con distribución multi-sucursal.
  static Future<UploadResult> uploadWithDistribution({
    required FormData formData,
    void Function(double progress, String phase)? onProgress,
    int maxRetries = 3,
  }) async {
    return uploadProduct(
      endpoint: '${_dio.options.baseUrl}/productos/distribucion',
      formData: formData,
      onProgress: onProgress,
      maxRetries: maxRetries,
    );
  }

  /// Actualiza un producto existente.
  static Future<UploadResult> updateProduct({
    required int productId,
    required FormData formData,
    void Function(double progress, String phase)? onProgress,
    int maxRetries = 3,
  }) async {
    return uploadProduct(
      endpoint: '${_dio.options.baseUrl}/productos/$productId',
      formData: formData,
      onProgress: onProgress,
      maxRetries: maxRetries,
    );
  }

  /// Crea un producto simple (sin distribución).
  static Future<UploadResult> createProduct({
    required FormData formData,
    void Function(double progress, String phase)? onProgress,
    int maxRetries = 3,
  }) async {
    return uploadProduct(
      endpoint: '${_dio.options.baseUrl}/productos',
      formData: formData,
      onProgress: onProgress,
      maxRetries: maxRetries,
    );
  }
}
