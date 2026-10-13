/// Subida de producto pendiente de reintento.
/// Guarda los datos del formulario y las imágenes comprimidas para
/// poder reintentar la subida sin perder información.
class PendingUpload {
  final String id;
  final String nombre;
  final bool isEditing;
  final int? productoId;

  /// Campos del formulario (Map<String, dynamic> serializable)
  final Map<String, dynamic> formFields;

  /// Rutas de las imágenes comprimidas (persistentes)
  final List<String> imagenPaths;

  /// Modo de subida: 'distribucion', 'editar', 'simple', 'local'
  final String modoSubida;

  String? lastError;

  PendingUpload({
    required this.id,
    required this.nombre,
    required this.isEditing,
    this.productoId,
    required this.formFields,
    required this.imagenPaths,
    required this.modoSubida,
    this.lastError,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'isEditing': isEditing,
      'productoId': productoId,
      'formFields': formFields,
      'imagenPaths': imagenPaths,
      'modoSubida': modoSubida,
      'lastError': lastError,
    };
  }

  factory PendingUpload.fromJson(Map<String, dynamic> json) {
    return PendingUpload(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Producto',
      isEditing: json['isEditing'] as bool? ?? false,
      productoId: json['productoId'] as int?,
      formFields: Map<String, dynamic>.from(json['formFields'] as Map? ?? {}),
      imagenPaths: List<String>.from(json['imagenPaths'] as List? ?? []),
      modoSubida: json['modoSubida'] as String? ?? 'simple',
      lastError: json['lastError'] as String?,
    );
  }
}
