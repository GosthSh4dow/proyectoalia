import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models/pending_upload.dart';
import 'api_service.dart';

class UploadResponse {
  final String? errorMsg;
  final Map<String, dynamic>? data;
  const UploadResponse({this.errorMsg, this.data});
}

/// Gestiona subidas de productos pendientes de reintento.
/// Guarda los datos y las imágenes comprimidas en almacenamiento persistente
/// para que el usuario pueda reintentar sin perder nada.
class PendingUploadService {
  static final PendingUploadService _instance = PendingUploadService._();
  factory PendingUploadService() => _instance;
  PendingUploadService._();

  static const String _prefsKey = 'pending_uploads_v1';
  static const int kMaxPendings = 20;
  static const int kMaxDiskBytes = 500 * 1024 * 1024; // 500MB
  final Dio _dio = ApiService().dio;

  /// Elimina el/los más antiguos si se excede el límite de 20 pendings
  /// o el límite de 500MB en disco. Mantiene SharedPreferences, no Hive.
  Future<void> removeOldestIfOverLimit() async {
    try {
      final all = await getAll();
      if (all.isEmpty) return;
      // Ordenar por id ascendente (id = timestamp + random => oldest first)
      all.sort((a, b) => a.id.compareTo(b.id));
      // 1) Límite de cantidad
      while (all.length >= kMaxPendings) {
        final oldest = all.removeAt(0);
        debugPrint('[PendingUploadService] removeOldestIfOverLimit: límite $kMaxPendings alcanzado, eliminando oldest ${oldest.id} (${oldest.nombre})');
        await remove(oldest.id);
      }
      // 2) Límite de disco 500MB
      await _enforceDiskLimit();
    } catch (e) {
      debugPrint('[PendingUploadService] removeOldestIfOverLimit error: $e');
    }
  }

  Future<void> _enforceDiskLimit() async {
    try {
      final all = await getAll();
      if (all.isEmpty) return;
      int total = 0;
      final Map<String, int> sizeById = {};
      for (final u in all) {
        int sz = 0;
        for (final p in u.imagenPaths) {
          try {
            final f = File(p);
            if (await f.exists()) sz += await f.length();
          } catch (e) {
            debugPrint('[PendingUploadService] _enforceDiskLimit stat error $p: $e');
          }
        }
        sizeById[u.id] = sz;
        total += sz;
      }
      debugPrint('[PendingUploadService] disk usage: $total bytes / $kMaxDiskBytes');
      if (total <= kMaxDiskBytes) return;
      all.sort((a, b) => a.id.compareTo(b.id)); // oldest first
      for (final u in all) {
        if (total <= kMaxDiskBytes) break;
        final sz = sizeById[u.id] ?? 0;
        debugPrint('[PendingUploadService] _enforceDiskLimit purgando ${u.id} size $sz');
        await remove(u.id);
        total -= sz;
      }
    } catch (e) {
      debugPrint('[PendingUploadService] _enforceDiskLimit error: $e');
    }
  }

  /// Comprime a WebP 1024px quality 85 si no está ya comprimida.
  /// Retorna el File a persistir (ya en destino) o el original si falla.
  Future<File> _maybeCompressToWebP(File src, String destBase) async {
    try {
      final lower = src.path.toLowerCase();
      if (lower.endsWith('.webp')) {
        debugPrint('[PendingUploadService] _maybeCompress: ${src.path} ya es webp, skip');
        return src;
      }
      // Si no termina en jpg/jpeg/png, igual intentamos comprimir
      final outPath = '$destBase.webp';
      final originalLen = await src.length().catchError((_) => -1);
      debugPrint('[PendingUploadService] _maybeCompress: comprimiendo ${src.path} ($originalLen bytes) -> $outPath (1024px q85 webp)');
      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        src.absolute.path,
        outPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.webp,
      );
      if (compressedXFile != null) {
        final cf = File(compressedXFile.path);
        if (await cf.exists()) {
          final newLen = await cf.length();
          debugPrint('[PendingUploadService] _maybeCompress OK: $originalLen -> $newLen bytes');
          return cf;
        } else {
          debugPrint('[PendingUploadService] _maybeCompress: compressed file no existe ${compressedXFile.path}');
        }
      } else {
        debugPrint('[PendingUploadService] _maybeCompress: compressAndGetFile retornó null para ${src.path}');
      }
      return src;
    } catch (e, st) {
      debugPrint('[PendingUploadService] _maybeCompress error ${src.path}: $e $st');
      return src;
    }
  }

  /// Copia las imágenes comprimidas a un directorio persistente y
  /// retorna la lista de nuevas rutas.
  /// Aplica compresión WebP si no está comprimida y logging defensivo.
  Future<List<String>> persistImages(String id, List<File> images) async {
    if (images.isEmpty) return [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final uploadDir = Directory('${dir.path}${Platform.pathSeparator}pending_uploads${Platform.pathSeparator}$id');
      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
      }

      final paths = <String>[];
      for (var i = 0; i < images.length; i++) {
        final src = images[i];
        try {
          if (!await src.exists()) {
            debugPrint('[PendingUploadService] persistImages: src no existe ${src.path} skip');
            continue;
          }
          final destBase = '${uploadDir.path}${Platform.pathSeparator}img_$i';
          final toPersist = await _maybeCompressToWebP(src, destBase);
          if (toPersist.path == src.path) {
            // No se comprimió (ya era webp o falló) -> copiar original
            final ext = src.path.split('.').last;
            final dest = File('$destBase.$ext');
            // Si src ya está en uploadDir (caso reintento), evitar copiar sobre sí mismo
            if (src.absolute.path != dest.absolute.path) {
              await src.copy(dest.path);
              paths.add(dest.path);
              debugPrint('[PendingUploadService] persistImages: copiado ${src.path} -> ${dest.path}');
            } else {
              paths.add(src.path);
            }
          } else {
            // Ya está en destino WebP vía compressAndGetFile
            paths.add(toPersist.path);
            debugPrint('[PendingUploadService] persistImages: webp persistido ${toPersist.path}');
          }
        } catch (e, st) {
          debugPrint('[PendingUploadService] persistImages error item $i: $e $st');
          continue;
        }
      }
      return paths;
    } catch (e, st) {
      debugPrint('[PendingUploadService] persistImages fatal: $e $st');
      return [];
    }
  }

  /// Guarda (o actualiza) una subida pendiente en SharedPreferences.
  Future<void> save(PendingUpload upload) async {
    try {
      // Salvaguarda: limitar a 20 y 500MB antes de guardar el nuevo
      await removeOldestIfOverLimit();
      final prefs = await SharedPreferences.getInstance();
      final all = await getAll();
      all.removeWhere((u) => u.id == upload.id);
      all.add(upload);
      // Enforce again después de añadir por si excede exactamente
      if (all.length > kMaxPendings) {
        all.sort((a, b) => a.id.compareTo(b.id));
        while (all.length > kMaxPendings) {
          final oldest = all.removeAt(0);
          debugPrint('[PendingUploadService] save: purgando oldest ${oldest.id} por exceso tras add');
          // borrar archivos del oldest
          try {
            final dir = await getApplicationDocumentsDirectory();
            final uploadDir = Directory('${dir.path}${Platform.pathSeparator}pending_uploads${Platform.pathSeparator}${oldest.id}');
            if (await uploadDir.exists()) await uploadDir.delete(recursive: true);
          } catch (e) {
            debugPrint('[PendingUploadService] save purge dir error ${oldest.id}: $e');
          }
        }
      }
      final jsonList = all.map((u) => u.toJson()).toList();
      final ok = await prefs.setString(_prefsKey, jsonEncode(jsonList));
      debugPrint('[PendingUploadService] save: ${upload.id} (${upload.nombre}) total=${all.length} ok=$ok');
      // Chequeo de disco post-save (defensivo)
      await _enforceDiskLimit();
    } catch (e, st) {
      debugPrint('[PendingUploadService] save error: $e $st');
    }
  }

  /// Retorna todas las subidas pendientes.
  Future<List<PendingUpload>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return [];
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => PendingUpload.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e, st) {
        debugPrint('[PendingUploadService] getAll jsonDecode error: $e $st raw=$raw');
        return [];
      }
    } catch (e, st) {
      debugPrint('[PendingUploadService] getAll prefs error: $e $st');
      return [];
    }
  }

  /// Retorna una subida pendiente por id.
  Future<PendingUpload?> get(String id) async {
    try {
      final all = await getAll();
      for (final u in all) {
        if (u.id == id) return u;
      }
      return null;
    } catch (e, st) {
      debugPrint('[PendingUploadService] get($id) error: $e $st');
      return null;
    }
  }

  /// Elimina TODAS las subidas pendientes y sus imágenes persistentes.
  /// Usado para limpiar pendientes antiguos (productos ya registrados).
  Future<void> clearAll() async {
    try {
      final all = await getAll();
      for (final u in all) {
        await remove(u.id);
      }
      debugPrint('[PendingUploadService] clearAll: ${all.length} eliminados');
    } catch (e, st) {
      debugPrint('[PendingUploadService] clearAll error: $e $st');
    }
  }

  /// Elimina la subida pendiente y sus imágenes persistentes.
  Future<void> remove(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAll();
      final before = all.length;
      all.removeWhere((u) => u.id == id);
      final jsonList = all.map((u) => u.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
      debugPrint('[PendingUploadService] remove: $id before=$before after=${all.length}');

      try {
        final dir = await getApplicationDocumentsDirectory();
        final uploadDir = Directory('${dir.path}${Platform.pathSeparator}pending_uploads${Platform.pathSeparator}$id');
        if (await uploadDir.exists()) {
          await uploadDir.delete(recursive: true);
          debugPrint('[PendingUploadService] remove: dir borrado $uploadDir');
        }
      } catch (e) {
        debugPrint('[PendingUploadService] remove dir error $id: $e');
      }
    } catch (e, st) {
      debugPrint('[PendingUploadService] remove($id) error: $e $st');
    }
  }

  /// Construye el FormData para el backend a partir de los campos del formulario
  /// y las rutas de imágenes comprimidas. `requestId` permite al backend
  /// detectar reintentos del mismo alta (idempotencia) y no duplicar productos.
  Future<FormData> buildFormData(
    Map<String, dynamic> formFields,
    List<String> imagenPaths, {
    String? requestId,
  }) async {
    final data = FormData();

    if (requestId != null && requestId.isNotEmpty) {
      data.fields.add(MapEntry('request_id', requestId));
    }

    formFields.forEach((key, value) {
      if (value != null && key != 'imagen' && key != 'imagenes_adicionales') {
        // Omitir fecha_caducidad vacía (el backend la rechaza con "Datos inválidos")
        if (key == 'fecha_caducidad' && (value.toString().isEmpty || value.toString() == 'null')) {
          return;
        }
        if (value is List) {
          data.fields.add(MapEntry(key, jsonEncode(value)));
        } else {
          data.fields.add(MapEntry(key, value.toString()));
        }
      }
    });

    for (var i = 0; i < imagenPaths.length; i++) {
      final path = imagenPaths[i];
      try {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('[PendingUploadService] buildFormData: file no existe skip $path');
          continue;
        }
        final filename = path.split(Platform.pathSeparator).last;
        final multipart = await MultipartFile.fromFile(
          path,
          filename: filename,
          contentType: _mimeTypeFor(filename),
        );
        if (i == 0) {
          data.files.add(MapEntry('imagen', multipart));
        } else {
          data.files.add(MapEntry('imagenes_adicionales', multipart));
        }
      } catch (e, st) {
        debugPrint('[PendingUploadService] buildFormData file error $path: $e $st');
        continue;
      }
    }

    return data;
  }

  MediaType? _mimeTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
  }

  /// Realiza la subida con reintentos. Retorna UploadResponse con errorMsg=null si tuvo éxito.
  Future<UploadResponse> enviar(
    PendingUpload upload, {
    void Function(int sent, int total)? onProgress,
  }) async {
    ApiService().setUploadTimeout();
    try {
      bool success = false;
      Map<String, dynamic>? responseData;

      for (int attempt = 0; attempt <= 3; attempt++) {
        try {
          if (attempt > 0) {
            final delay = Duration(seconds: (1 << (attempt - 1)));
            debugPrint('[PendingUploadService] enviar retry attempt $attempt delay $delay para ${upload.id}');
            await Future.delayed(delay);
          }

          // IMPORTANTE: reconstruir FormData en cada intento,
          // los streams de archivo solo pueden leerse una vez.
          final attemptData = await buildFormData(
            upload.formFields,
            upload.imagenPaths,
            requestId: upload.id,
          );

          dynamic response;
          if (upload.modoSubida == 'distribucion') {
            response = await _dio.post(
              '$BASE_URL/productos/distribucion',
              data: attemptData,
              onSendProgress: onProgress,
            );
          } else if (upload.modoSubida == 'editar' && upload.productoId != null) {
            response = await _dio.put(
              '$BASE_URL/productos/${upload.productoId}',
              data: attemptData,
              onSendProgress: onProgress,
            );
          } else {
            response = await _dio.post(
              '$BASE_URL/productos',
              data: attemptData,
              onSendProgress: onProgress,
            );
          }
          success = true;
          // Defensa extra: aunque Dio no lance excepción (p. ej. por un 4xx/5xx
          // resuelto por el interceptor de 401), nunca reportar éxito con una
          // respuesta no-2xx. Si el backend no confirmó la transacción, esto
          // se muestra como fallo en lugar de "subido".
          final status = response?.statusCode ?? 0;
          if (status < 200 || status >= 300) {
            throw DioException(
              requestOptions: response!.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              message: 'HTTP $status',
            );
          }
          if (response?.data is Map<String, dynamic>) {
            responseData = response.data as Map<String, dynamic>;
          }
          debugPrint('[PendingUploadService] enviar OK attempt $attempt status $status id=${upload.id}');

          if (success) break;
        } on DioException catch (e, st) {
          debugPrint('[PendingUploadService] enviar DioException attempt $attempt id=${upload.id} type=${e.type} status=${e.response?.statusCode} msg=${e.message} $st');
          String detail = _errorMessage(e);
          final status = e.response?.statusCode;
          if (e.response != null) {
            detail += ' | HTTP ${e.response!.statusCode}';
            if (e.response!.data != null) {
              detail += ' | ${e.response!.data}';
            }
          }
          // No reintentar errores del cliente (validación, duplicado, permisos,
          // etc.): reintentarlos no arregla nada. Gracias a la idempotencia por
          // request_id, un reintento de un 4xx tampoco se convertiría en éxito.
          // Solo reintentamos errores transitorios (5xx, timeout, conexión).
          final isClientError = status != null && status >= 400 && status < 500 && status != 429;
          upload.lastError = detail;
          if (isClientError) {
            debugPrint('[PendingUploadService] enviar clientError no reintenta $status');
            break;
          }
          if (attempt == 3) {
            debugPrint('[PendingUploadService] enviar max retries alcanzado');
            break;
          }
        } catch (e, st) {
          debugPrint('[PendingUploadService] enviar catch attempt $attempt id=${upload.id} error $e $st');
          upload.lastError = 'Error: $e';
          if (attempt == 3) break;
        }
      }

      if (success) {
        upload.lastError = null;
        return UploadResponse(errorMsg: null, data: responseData);
      }
      return UploadResponse(errorMsg: upload.lastError ?? 'Error desconocido');
    } finally {
      ApiService().resetTimeout();
    }
  }

  String _errorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de espera agotado';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Sin conexión a internet';
    } else if (e.response?.statusCode != null) {
      return 'Error del servidor (${e.response!.statusCode})';
    } else {
      return 'Error de conexión';
    }
  }
}
