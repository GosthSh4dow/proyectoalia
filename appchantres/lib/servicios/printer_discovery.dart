import 'package:dio/dio.dart';

class PrinterDiscovery {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
      sendTimeout: const Duration(seconds: 2),
    ),
  );

  static Future<List<Map<String, dynamic>>> discoverPrinters() async {
    List<Map<String, dynamic>> availablePrinters = [];

    final commonHosts = [
      'http://localhost:8009',
      'http://192.168.1.100:8009',
      'http://192.168.1.200:8009',
      'http://192.168.0.100:8009',
      'http://10.0.0.100:8009',
    ];

    for (String host in commonHosts) {
      try {
        final response = await _dio.get(
          '$host/',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 200) {
          availablePrinters.add({
            'host': host,
            'name': 'Impresora en $host',
            'type': 'thermal',
            'status': 'disponible'
          });
        }
      } catch (e) {
        continue;
      }
    }

    return availablePrinters;
  }

  static Future<bool> testPrinterConnection(String url) async {
    try {
      String testContent = "\x1B\x40" +
          "PRUEBA\n" +
          "---\n" +
          "OK\n";

      final response = await _dio.post(
        url,
        data: {'conteudo': testContent},
        options: Options(
          validateStatus: (status) => status != null,
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> detectLocalPrinter() async {
    final printers = await discoverPrinters();
    if (printers.isNotEmpty) {
      return printers.first;
    }
    return null;
  }
}
