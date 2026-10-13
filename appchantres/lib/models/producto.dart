import 'producto_maestro.dart';
import 'producto_codigo.dart';
import 'dart:convert';

import 'producto_variante.dart';

class Producto {
  int id;
  String nombre;
  String codigoBarras;
  String imagen;
  double precioVenta;
  double costo;
  int stock;
  List<dynamic>? promociones;
  dynamic categoria;
  
  // Nuevos campos para soporte multi-sucursal y códigos alternativos
  int? productoMaestroId;
  ProductoMaestro? productoMaestro;
  List<ProductoCodigo>? codigos;
  List<ProductoVariante>? variantes; // New field
  Map<String, dynamic>? sucursal;
  List<dynamic>? colores;

  Producto({
    required this.id,
    required this.nombre,
    required this.codigoBarras,
    required this.imagen,
    required this.precioVenta,
    required this.costo,
    required this.stock,
    this.promociones,
    this.categoria,
    this.productoMaestroId,
    this.productoMaestro,
    this.codigos,
    this.variantes,
    this.sucursal,
    this.colores,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'],
      nombre: json['nombre'],
      codigoBarras: json['codigo_barras'] ?? '',
      imagen: json['imagen'] ?? '',
      precioVenta: double.parse((json['precio_venta'] ?? 0).toString()),
      costo: double.parse((json['costo'] ?? 0).toString()),
      stock: json['stock'] ?? 0,
      promociones: json['promociones'],
      categoria: json['categoria'],
      productoMaestroId: json['producto_maestro_id'],
      productoMaestro: json['productoMaestro'] != null
          ? ProductoMaestro.fromJson(json['productoMaestro'])
          : null,
      codigos: json['codigos'] != null
          ? (json['codigos'] as List)
              .map((c) => ProductoCodigo.fromJson(c))
              .toList()
          : [],
      variantes: json['variantes'] != null
          ? (json['variantes'] as List)
              .map((v) => ProductoVariante.fromJson(v))
              .toList()
          : [],
      sucursal: json['sucursal'],
      colores: json['colores'] is String 
          ? (json['colores'].toString().startsWith('[') 
              ? jsonDecode(json['colores']) 
              : []) 
          : json['colores'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo_barras': codigoBarras,
      'imagen': imagen,
      'precio_venta': precioVenta,
      'costo': costo,
      'stock': stock,
      'promociones': promociones,
      'categoria': categoria,
      'producto_maestro_id': productoMaestroId,
      // No serializamos objetos complejos anidados para envío simple
    };
  }
}
