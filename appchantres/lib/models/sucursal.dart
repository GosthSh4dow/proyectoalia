class Sucursal {
  final int id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final bool? esBodega;

  Sucursal({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.esBodega,
  });

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    return Sucursal(
      id: json['id'],
      nombre: json['nombre'],
      direccion: json['direccion'],
      telefono: json['telefono'],
      esBodega: json['es_bodega'] == true || json['es_bodega'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'es_bodega': esBodega,
    };
  }
}
