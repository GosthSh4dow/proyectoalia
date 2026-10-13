class Cliente {
  int id;
  String nombreCompleto;
  String ci;

  Cliente({
    required this.id,
    required this.nombreCompleto,
    required this.ci,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id_cliente'],
      nombreCompleto: json['nombre_completo'],
      ci: json['ci'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_cliente': id,
      'nombre_completo': nombreCompleto,
      'ci': ci,
    };
  }
}
