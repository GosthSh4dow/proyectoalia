import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressResult {
  final File? file;
  final int originalSize;
  final int compressedSize;

  ImageCompressResult({this.file, this.originalSize = 0, this.compressedSize = 0});
}

/// Comprime una imagen a JPEG usando flutter_image_compress (nativo).
/// El backend solo acepta imágenes JPEG (.jpg).
/// Si el archivo ya es pequeño (<200KB), no comprime.
Future<File?> compressImage(File file) async {
  try {
    final originalBytes = await file.readAsBytes();

    // Si el archivo ya es pequeño, no comprimir
    if (originalBytes.length < 200 * 1024) {
      return file;
    }

    // Obtener directorio temporal
    final dir = await getTemporaryDirectory();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final outPath = '${dir.path}${Platform.pathSeparator}compressed_${nameWithoutExt}.jpg';

    // Comprimir a JPEG usando flutter_image_compress (nativo Android/iOS)
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      outPath,
      format: CompressFormat.jpeg,
      quality: 82, // Calidad 82 = buena relación tamaño/calidad
      minWidth: 1920,
      minHeight: 1920,
    );

    if (result != null) {
      return File(result.path);
    }

    // Fallback: retornar original si falla
    return file;
  } catch (e) {
    return _compressFallback(file);
  }
}

/// Fallback: compresión JPG usando image package (si WebP falla)
Future<File?> _compressFallback(File file) async {
  try {
    final originalBytes = await file.readAsBytes();
    if (originalBytes.length < 200 * 1024) return file;

    final outPath = await Isolate.run(() {
      return _compressInIsolate(originalBytes, file.path);
    });

    return File(outPath);
  } catch (e) {
    return file;
  }
}

/// Comprime y retorna info detallada (para mostrar ahorro de espacio)
Future<ImageCompressResult> compressImageWithInfo(File file) async {
  try {
    final originalBytes = await file.readAsBytes();
    final originalSize = originalBytes.length;

    if (originalSize < 200 * 1024) {
      return ImageCompressResult(file: file, originalSize: originalSize, compressedSize: originalSize);
    }

    final compressedFile = await compressImage(file);
    if (compressedFile != null && await compressedFile.exists()) {
      final compressedSize = await compressedFile.length();
      return ImageCompressResult(
        file: compressedFile,
        originalSize: originalSize,
        compressedSize: compressedSize,
      );
    }

    return ImageCompressResult(file: file, originalSize: originalSize, compressedSize: originalSize);
  } catch (e) {
    return ImageCompressResult(file: file);
  }
}

String _compressInIsolate(List<int> bytes, String originalPath) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return originalPath;

  img.Image resized = image;
  if (image.width > 1920) {
    resized = img.copyResize(image, width: 1920);
  }

  final jpg = img.encodeJpg(resized, quality: 80);

  final fileName = originalPath.split(Platform.pathSeparator).last;
  final outPath = "${Platform.environment['TEMP'] ?? '/tmp'}${Platform.pathSeparator}compressed_$fileName";

  final outFile = File(outPath);
  outFile.writeAsBytesSync(jpg);
  return outPath;
}
