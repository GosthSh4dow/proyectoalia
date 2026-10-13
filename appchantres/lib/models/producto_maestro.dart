import 'producto.dart';

class ProductoMaestro {
  final int id;
  final String nombre;
  final String? descripcionBase;
  final String? imagenCompartida;
  final int proveedorId;
  final int categoriaId;
  final bool activo;
  final Map<String, dynamic>? proveedor;
  final Map<String, dynamic>? categoria;
  final List<Producto>? instancias;

  ProductoMaestro({
    required this.id,
    required this.nombre,
    this.descripcionBase,
    this.imagenCompartida,
    required this.proveedorId,
    required this.categoriaId,
    required this.activo,
    this.proveedor,
    this.categoria,
    this.instancias,
  });

  factory ProductoMaestro.fromJson(Map<String, dynamic> json) {
    return ProductoMaestro(
      id: json['id'],
      nombre: json['nombre'],
      descripcionBase: json['descripcion_base'],
      imagenCompartida: json['imagen_compartida'],
      proveedorId: json['proveedor_id'],
      categoriaId: json['categoria_id'],
      activo: json['activo'] == true || json['activo'] == 1,
      proveedor: json['proveedor'],
      categoria: json['categoria'],
      instancias: json['instancias'] != null
          ? (json['instancias'] as List)
              .map((i) => Producto.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion_base': descripcionBase,
      'imagen_compartida': imagenCompartida,
      'proveedor_id': proveedorId,
      'categoria_id': categoriaId,
      'activo': activo,
      // No incluimos objetos anidados complejos en toJson para evitar redundancia al enviar
    };
  }
}
