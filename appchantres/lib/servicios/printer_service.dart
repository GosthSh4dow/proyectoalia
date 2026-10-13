import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'receipt_builder.dart';
import 'printer_discovery.dart';

export 'receipt_builder.dart';
export 'printer_discovery.dart';

class PrinterService {
  // ─── Settings ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPrinterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('printerSettings');
    if (settingsJson != null) {
      try {
        return jsonDecode(settingsJson);
      } catch (e) {
        return _defaultSettings();
      }
    }
    return _defaultSettings();
  }

  static Map<String, dynamic> _defaultSettings() => {
        'printerHost': 'http://127.0.0.1:8009/',
        'printerType': 'epson',
        'enabled': true,
      };

  static Future<void> savePrinterSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerSettings', jsonEncode(settings));
  }

  // ─── Discovery ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> detectLocalPrinter() =>
      PrinterDiscovery.detectLocalPrinter();

  static Future<List<Map<String, dynamic>>> discoverPrinters() =>
      PrinterDiscovery.discoverPrinters();

  static Future<bool> testPrinterConnection(String host) =>
      PrinterDiscovery.testPrinterConnection(host);

  // ─── Printing ─────────────────────────────────────────────────────────────

  static Future<void> printReciboEpson(
    Map<String, dynamic> ventaInfo,
    List<dynamic> detallesInfo,
    Map<String, dynamic>? clienteData,
    bool noReceiptFlag,
    num montoEntregadoValue,
    num cambioValue,
  ) async {
    final settings = await getPrinterSettings();
    if (!(settings['enabled'] ?? true)) {
      throw Exception("La impresión está deshabilitada en la configuración");
    }
    final printerHost = settings['printerHost'] ?? 'http://127.0.0.1:8009/';

    final recibo = ReceiptBuilder.buildEpsonReceipt(
      ventaInfo: ventaInfo,
      detalles: detallesInfo,
      cliente: clienteData,
      noReceipt: noReceiptFlag,
      montoEntregado: montoEntregadoValue,
      cambio: cambioValue,
    );

    await _sendToPrinter(printerHost, recibo);
  }

  static Future<String> getTextReceipt(
    Map<String, dynamic> ventaInfo,
    List<dynamic> detallesInfo,
    Map<String, dynamic>? clienteData,
    num montoEntregadoValue,
    num cambioValue,
  ) async {
    return ReceiptBuilder.buildTextReceipt(
      ventaInfo: ventaInfo,
      detalles: detallesInfo,
      cliente: clienteData,
      montoEntregado: montoEntregadoValue,
      cambio: cambioValue,
    );
  }

  static Future<void> printBarcodeLabel({
    required String codigo,
    required String nombre,
    required num precio,
  }) async {
    final settings = await getPrinterSettings();
    if (!(settings['enabled'] ?? true)) {
      throw Exception("La impresión está deshabilitada en la configuración");
    }
    final printerHost = settings['printerHost'] ?? 'http://127.0.0.1:8009/';

    final label = ReceiptBuilder.buildBarcodeLabel(
      codigo: codigo,
      nombre: nombre,
      precio: precio,
    );

    await _sendToPrinter(printerHost, label);
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  static Future<void> _sendToPrinter(String printerHost, String content) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final response = await dio.post(printerHost, data: {'conteudo': content});

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode != null) {
        throw Exception("Error HTTP ${response.statusCode}: ${response.data}");
      } else {
        throw Exception("Error desconocido en la impresión");
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
            "Timeout: La impresora no responde. Verifique que esté conectada.");
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
            "Timeout: La impresora tardó demasiado. Verifique la conexión.");
      } else if (e.type == DioExceptionType.unknown &&
          e.error is SocketException) {
        throw Exception(
            "Error de conexión: Verifique la URL de la impresora (${printerHost.replaceAll(RegExp(r'/+$'), '')})");
      } else {
        throw Exception("Error de conexión: ${e.message}");
      }
    } catch (e) {
      throw Exception("Error en la impresión: ${e.toString()}");
    }
  }
}
