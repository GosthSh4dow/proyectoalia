import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import 'api_service.dart';

String fmtFecha(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Líneas vendidas agregadas por producto (con utilidad).
class LineaVendida {
  final int idProducto;
  final String codigoBarras;
  final String nombre;
  final int cantidad;
  final double precioPromedio;
  final double ingreso;
  final double costoUnitario;
  final double costo;
  final double utilidad;
  final double margenPct;
  final int nroTickets;

  LineaVendida({
    required this.idProducto,
    required this.codigoBarras,
    required this.nombre,
    required this.cantidad,
    required this.precioPromedio,
    required this.ingreso,
    required this.costoUnitario,
    required this.costo,
    required this.utilidad,
    required this.margenPct,
    required this.nroTickets,
  });

  static double _d(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);
  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  factory LineaVendida.fromJson(Map<String, dynamic> j) => LineaVendida(
        idProducto: _i(j['id_producto']),
        codigoBarras: '${j['codigo_barras'] ?? ''}',
        nombre: '${j['nombre'] ?? 'Sin nombre'}',
        cantidad: _i(j['cantidad']),
        precioPromedio: _d(j['precio_promedio']),
        ingreso: _d(j['ingreso_linea']),
        costoUnitario: _d(j['costo_unitario']),
        costo: _d(j['costo_linea']),
        utilidad: _d(j['utilidad_linea']),
        margenPct: _d(j['margen_pct']),
        nroTickets: _i(j['nro_tickets']),
      );
}

class LineasPage {
  final List<LineaVendida> items;
  final Map<String, dynamic> totales;
  final int total;
  final int page;
  final int limit;
  LineasPage(
      {required this.items,
      required this.totales,
      required this.total,
      required this.page,
      required this.limit});
  bool get hasMore => page * limit < total;
}

class ReportesService {
  final Dio _dio = ApiService().dio;

  /// Qué se vendió, paginado (usa filtros del reporte actual).
  Future<LineasPage> fetchLineas({
    required DateTime inicio,
    required DateTime fin,
    int? sucursalId,
    int page = 1,
    int limit = 20,
    String orderBy = 'utilidad',
  }) async {
    final qp = <String, dynamic>{
      'startDate': fmtFecha(inicio),
      'endDate': fmtFecha(fin),
      'page': page,
      'limit': limit,
      'orderBy': orderBy,
    };
    if (sucursalId != null) qp['sucursalId'] = sucursalId;
    final resp = await _dio.get('$BASE_URL/reportes/contable/lineas',
        queryParameters: qp);
    final d = resp.data as Map<String, dynamic>;
    final items = ((d['data'] as List? ?? [])
            .whereType<Map<String, dynamic>>())
        .map(LineaVendida.fromJson)
        .toList();
    return LineasPage(
      items: items,
      totales: Map<String, dynamic>.from(d['totales'] ?? {}),
      total: (d['total'] ?? 0) as int,
      page: (d['page'] ?? page) as int,
      limit: (d['limit'] ?? limit) as int,
    );
  }

  /// Descarga el CSV del backend (con filtros) y lo comparte.
  /// Retorna true si se compartió.
  Future<bool> exportarYCompartir({
    required DateTime inicio,
    required DateTime fin,
    int? sucursalId,
  }) async {
    try {
      final qp = <String, dynamic>{
        'format': 'csv',
        'startDate': fmtFecha(inicio),
        'endDate': fmtFecha(fin),
      };
      if (sucursalId != null) qp['sucursalId'] = sucursalId;
      final resp = await _dio.get(
        '$BASE_URL/reportes/exportar',
        queryParameters: qp,
        options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 60)),
      );
      final dir = await getTemporaryDirectory();
      final nombre =
          'reporte_${fmtFecha(inicio)}_${fmtFecha(fin)}_suc${sucursalId ?? "todas"}.csv';
      final file = File('${dir.path}/$nombre');
      final bytes = resp.data is List<int>
          ? (resp.data as List<int>)
          : List<int>.from(resp.data);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: nombre)],
        subject: 'Reporte $nombre',
      );
      return true;
    } catch (e) {
      debugPrint('[reportes] exportar error: $e');
      return false;
    }
  }
}
