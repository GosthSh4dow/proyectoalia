import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../api.dart';

class ProductListItemCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final Function(Map<String, dynamic>) onEdit;
  final Function(dynamic) onDelete;
  final Function(Map<String, dynamic>) onPrint;
  final bool isLocalServerMode;

  const ProductListItemCard({
    Key? key,
    required this.producto,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    this.isLocalServerMode = false,
  }) : super(key: key);

  bool _isLocalProduct() {
    final imagenUrl = producto['imagen_url'];
    if (imagenUrl == null) return false;
    return imagenUrl.contains(':8000');
  }

  @override
  Widget build(BuildContext context) {
    final nombre = producto['nombre'] ?? 'Sin nombre';
    final stock = producto['stock'] ?? 0;
    final precio = producto['precio_venta'] ?? '0.00';
    final isLocalProduct = isLocalServerMode && _isLocalProduct();
    final imageUrl = getImageUrl(producto['imagen_url'] ?? producto['imagen']);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isAdmin = userProvider.isAdmin;

    // Sucursales en UNA sola línea (antes 2 líneas + header empujaban
    // el precio fuera de la tarjeta y se recortaba). Admin ve "A: 5 · B: 3".
    String? sucursalLine;
    if (isAdmin && producto['sucursales_info'] is List && (producto['sucursales_info'] as List).isNotEmpty) {
      final infos = (producto['sucursales_info'] as List);
      final parts = infos.take(2).map((info) {
        final n = (info is Map ? info['nombre']?.toString() ?? '' : '').trim();
        final s = info is Map ? info['stock']?.toString() ?? '0' : '0';
        final short = n.length > 10 ? n.substring(0, 10) : n;
        return '$short: $s';
      }).join(' · ');
      sucursalLine = infos.length > 2 ? '$parts +${infos.length - 2}' : parts;
    } else if (producto['sucursal'] != null) {
      final sName = producto['sucursal']['nombre']?.toString() ?? '';
      sucursalLine = '$sName: $stock';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // === IMAGEN ===
          Expanded(
            flex: 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    color: Colors.grey.shade50,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                            maxWidthDiskCache: 400,
                            maxHeightDiskCache: 400,
                            cacheKey: imageUrl,
                            placeholder: (_, __) => const Center(
                              child: SpinKitPulse(color: Color(0xFFE879F9), size: 24.0),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(LineIcons.imageFile, color: Colors.grey.shade300, size: 28),
                            ),
                          )
                        : Center(
                            child: Icon(LineIcons.imageFile, color: Colors.grey.shade300, size: 28),
                          ),
                  ),
                ),
                // Badge Local
                if (isLocalProduct)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.white, size: 8),
                          const SizedBox(width: 3),
                          Text('Local', style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                // Menu
                Positioned(
                  top: 6,
                  right: 6,
                  child: _buildActionButton(context),
                ),
              ],
            ),
          ),

          // === INFO (precio y sucursal siempre visibles: van primero) ===
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre
                Text(
                  nombre.toString(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Precio + Stock (arriba: nunca se recorta)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Bs. $precio',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFFC026D3),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Stock: $stock',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: stock.toString() == '0' ? Colors.red.shade500 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                // Sucursal en una sola línea con icono
                if (sucursalLine != null && sucursalLine!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LineIcons.mapMarker, size: 10, color: const Color(0xFFC026D3)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          sucursalLine!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],

                // Colores (si hay, compacto al final)
                if (producto['colores'] != null) _buildColorDots(),
              ],
            ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorDots() {
    List<dynamic> colors = [];
    if (producto['colores'] is List) {
      colors = producto['colores'];
    } else if (producto['colores'] is String) {
      try { colors = jsonDecode(producto['colores']); } catch (_) {}
    }
    if (colors.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Wrap(
        spacing: 3,
        runSpacing: 2,
        children: colors.take(5).map<Widget>((c) {
          String hex = c.toString().replaceAll('#', '');
          if (hex.length == 6) hex = 'FF$hex';
          final color = Color(int.tryParse(hex, radix: 16) ?? 0xFF000000);
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
          );
        }).toList()
          ..add(
            colors.length > 5
                ? Text('+${colors.length - 5}', style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey))
                : const SizedBox.shrink(),
          ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_horiz, color: Colors.grey.shade600, size: 16),
      ),
      onSelected: (String value) {
        if (value == 'edit') onEdit(producto);
        else if (value == 'delete') onDelete(producto['id']);
        else if (value == 'print') onPrint(producto);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(LineIcons.edit, color: Color(0xFFC026D3), size: 18),
              const SizedBox(width: 10),
              Text('Editar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'print',
          child: Row(
            children: [
              Icon(LineIcons.print, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 10),
              Text('Imprimir', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(LineIcons.trash, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 10),
              Text('Eliminar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    );
  }
}
