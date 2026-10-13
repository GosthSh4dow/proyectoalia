class Anuncio {
  final int? id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final DateTime fechaInicio;
  final DateTime fechaExpiracion;
  final bool activo;
  final bool bloqueante;
  final String? imagen;
  final dynamic creador;

  Anuncio({
    this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaExpiracion,
    this.activo = true,
    this.bloqueante = false,
    this.imagen,
    this.creador,
  });

  factory Anuncio.fromJson(Map<String, dynamic> json) {
    return Anuncio(
      id: json['id'],
      titulo: json['titulo'] ?? '',
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo'] ?? 'info',
      fechaInicio: json['fecha_inicio'] != null 
          ? DateTime.parse(json['fecha_inicio']).toLocal() 
          : DateTime.now(),
      fechaExpiracion: json['fecha_expiracion'] != null 
          ? DateTime.parse(json['fecha_expiracion']).toLocal() 
          : DateTime.now().add(const Duration(days: 7)),
      activo: json['activo'] is bool ? json['activo'] : (json['activo'] == 1 || json['activo'] == '1'),
      bloqueante: json['bloqueante'] is bool ? json['bloqueante'] : (json['bloqueante'] == 1 || json['bloqueante'] == '1'),
      imagen: json['imagen'],
      creador: json['creador'],
    );
  }

  Map<String, dynamic> toJson({int? creatorId}) {
    return {
      if (id != null) 'id': id,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
      'fecha_expiracion': fechaExpiracion.toUtc().toIso8601String(),
      'activo': activo,
      'bloqueante': bloqueante,
      if (imagen != null) 'imagen': imagen,
      if (creatorId != null) 'id_usuario_creador': creatorId,
    };
  }

  Anuncio copyWith({
    int? id,
    String? titulo,
    String? mensaje,
    String? tipo,
    DateTime? fechaInicio,
    DateTime? fechaExpiracion,
    bool? activo,
    bool? bloqueante,
    String? imagen,
    dynamic creador,
  }) {
    return Anuncio(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      tipo: tipo ?? this.tipo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      activo: activo ?? this.activo,
      bloqueante: bloqueante ?? this.bloqueante,
      imagen: imagen ?? this.imagen,
      creador: creador ?? this.creador,
    );
  }
}
