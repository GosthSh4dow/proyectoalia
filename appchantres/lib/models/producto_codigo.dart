class ProductoCodigo {
  final int id;
  final int productoId;
  final String codigo;
  final String tipo; // 'barras', 'sku', 'interno', 'otro'
  final bool esPrincipal;

  ProductoCodigo({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.tipo,
    required this.esPrincipal,
  });

  factory ProductoCodigo.fromJson(Map<String, dynamic> json) {
    return ProductoCodigo(
      id: json['id'],
      productoId: json['producto_id'],
      codigo: json['codigo'],
      tipo: json['tipo'],
      esPrincipal: json['es_principal'] == true || json['es_principal'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'producto_id': productoId,
      'codigo': codigo,
      'tipo': tipo,
      'es_principal': esPrincipal,
    };
  }
}
