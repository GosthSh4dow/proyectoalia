class ProductFormData {
  String nombre;
  String descripcion;
  double costo;
  double precioVenta;
  int stock;
  String codigoBarras;
  String categoria;
  String proveedor;
  List<String> colores;
  List<BranchDistribution> distribuciones;
  List<String> camposFaltantes;

  // Boolean flags (binary switches)
  bool esParaVenta;
  bool distribucionMultiSucursal;
  bool controlDeStock;

  ProductFormData({
    this.nombre = '',
    this.descripcion = '',
    this.costo = 0,
    this.precioVenta = 0,
    this.stock = 1,
    this.codigoBarras = '',
    this.categoria = 'General',
    this.proveedor = 'Akzana',
    this.colores = const [],
    this.distribuciones = const [],
    this.camposFaltantes = const [],
    this.esParaVenta = true,
    this.distribucionMultiSucursal = false,
    this.controlDeStock = true,
  });

  factory ProductFormData.fromJson(Map<String, dynamic> json) {
    return ProductFormData(
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      costo: _parseDouble(json['costo']),
      precioVenta: _parseDouble(json['precio_venta']),
      stock: _parseInt(json['stock']),
      codigoBarras: json['codigo_barras']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? 'General',
      proveedor: json['proveedor']?.toString() ?? 'Akzana',
      colores: _parseStringList(json['colores']),
      distribuciones: _parseDistribuciones(json['distribuciones']),
      camposFaltantes: _parseStringList(json['campos_faltantes']),
      esParaVenta: json['es_para_venta'] ?? true,
      distribucionMultiSucursal: json['distribucion_multi_sucursal'] ?? false,
      controlDeStock: json['control_de_stock'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'costo': costo,
      'precio_venta': precioVenta,
      'stock': stock,
      'codigo_barras': codigoBarras,
      'categoria': categoria,
      'proveedor': proveedor,
      'colores': colores,
      'distribuciones': distribuciones.map((d) => d.toJson()).toList(),
      'campos_faltantes': camposFaltantes,
      'es_para_venta': esParaVenta,
      'distribucion_multi_sucursal': distribucionMultiSucursal,
      'control_de_stock': controlDeStock,
    };
  }

  ProductFormData copy() {
    return ProductFormData(
      nombre: nombre,
      descripcion: descripcion,
      costo: costo,
      precioVenta: precioVenta,
      stock: stock,
      codigoBarras: codigoBarras,
      categoria: categoria,
      proveedor: proveedor,
      colores: List.from(colores),
      distribuciones: distribuciones.map((d) => d.copy()).toList(),
      camposFaltantes: List.from(camposFaltantes),
      esParaVenta: esParaVenta,
      distribucionMultiSucursal: distribucionMultiSucursal,
      controlDeStock: controlDeStock,
    );
  }

  bool get tieneDatos => nombre.isNotEmpty || costo > 0 || precioVenta > 0;

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      if (value.startsWith('[')) {
        try {
          return List<String>.from(
            (value as List).map((e) => e.toString()),
          );
        } catch (_) {
          return [];
        }
      }
      return [value];
    }
    return [];
  }

  static List<BranchDistribution> _parseDistribuciones(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .map((d) => BranchDistribution.fromJson(d as Map<String, dynamic>))
        .toList();
  }
}

class BranchDistribution {
  String nombreSucursal;
  int cantidad;

  BranchDistribution({
    required this.nombreSucursal,
    required this.cantidad,
  });

  factory BranchDistribution.fromJson(Map<String, dynamic> json) {
    return BranchDistribution(
      nombreSucursal: json['nombre_sucursal']?.toString() ?? '',
      cantidad: ProductFormData._parseInt(json['cantidad']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre_sucursal': nombreSucursal,
      'cantidad': cantidad,
    };
  }

  BranchDistribution copy() {
    return BranchDistribution(
      nombreSucursal: nombreSucursal,
      cantidad: cantidad,
    );
  }
}
