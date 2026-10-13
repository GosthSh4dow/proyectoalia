class ProductoVariante {
  int? id;
  int? productoId;
  String color;
  int cantidad;
  String? imagenUrl;

  ProductoVariante({
    this.id,
    this.productoId,
    required this.color,
    required this.cantidad,
    this.imagenUrl,
  });

  factory ProductoVariante.fromJson(Map<String, dynamic> json) {
    return ProductoVariante(
      id: json['id'],
      productoId: json['producto_id'],
      color: json['color'] ?? '',
      cantidad: json['cantidad'] ?? 0,
      imagenUrl: json['imagen_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'producto_id': productoId,
      'color': color,
      'cantidad': cantidad,
      'imagen_url': imagenUrl,
    };
  }
}
