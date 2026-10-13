import 'package:flutter/foundation.dart';

/// Anti-duplicados para el lector continuo estilo supermercado.
///
/// El plugin ya filtra con `noDuplicates`, esta es la segunda capa:
/// mismo código ignorado 1.5s, códigos distintos pasan en ráfaga.
class ScannerCooldown {
  ScannerCooldown({this.cooldown = const Duration(milliseconds: 1500)});

  final Duration cooldown;
  final Map<String, DateTime> _ultimaLectura = {};

  /// true = ignorar (duplicado dentro de la ventana).
  bool esDuplicado(String codigo) {
    final norm = codigo.trim().toUpperCase();
    if (norm.isEmpty) return true;
    final now = DateTime.now();
    final prev = _ultimaLectura[norm];
    if (prev != null && now.difference(prev) < cooldown) {
      debugPrint('[scanner] duplicado ignorado codigo=$norm');
      return true;
    }
    _ultimaLectura[norm] = now;
    // LRU simple: no crecer sin cota en turnos largos.
    if (_ultimaLectura.length > 300) {
      final keys = _ultimaLectura.keys.toList()
        ..sort((a, b) => _ultimaLectura[a]!.compareTo(_ultimaLectura[b]!));
      for (final k in keys.take(_ultimaLectura.length - 300)) {
        _ultimaLectura.remove(k);
      }
    }
    return false;
  }

  /// Códigos parciales/reflejos: longitud mínima 4.
  static bool esValido(String codigo) => codigo.trim().length >= 4;

  void limpiar() => _ultimaLectura.clear();
}
