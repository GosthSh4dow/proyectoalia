import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/producto.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api.dart';

class SalesProductCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  final double precioFinal;
  final bool es2x1;
  final int cantidadEnCarrito;

  const SalesProductCard({
    Key? key,
    required this.producto,
    required this.onTap,
    required this.precioFinal,
    this.es2x1 = false,
    this.cantidadEnCarrito = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var stock = producto.stock;
    bool enCarrito = cantidadEnCarrito > 0;
    bool descuentoActivo = precioFinal < producto.precioVenta;
    
    String? imageUrl;
    if (producto.imagen.isNotEmpty) {
      imageUrl = '$BASE_URL${producto.imagen}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen 
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    color: Colors.grey.shade50,
                    width: double.infinity,
                    child: (imageUrl != null)
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SpinKitPulse(color: Color(0xFFE879F9), size: 30.0),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(LineIcons.imageFile,
                                  color: Colors.grey.shade300, size: 32),
                            ),
                          )
                        : Center(
                            child: Icon(LineIcons.imageFile,
                                color: Colors.grey.shade300, size: 32),
                          ),
                  ),
                ),
                // 2x1 Badge
                if (es2x1)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: Text(
                        '2 x 1',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // En Carrito Badge
                if (enCarrito)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: Text(
                        '$cantidadEnCarrito',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Add to cart button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC026D3), // Fuchsia
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC026D3).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: const Icon(LineIcons.plus, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Info Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  producto.nombre,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                    color: Colors.grey.shade800,
                    height: 1.2
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(LineIcons.boxes, size: 12, color: Colors.grey.shade400),
                    SizedBox(width: 4.w),
                    Text(
                      'Stock: $stock',
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        color: stock < 5 ? Colors.red.shade400 : Colors.grey.shade500,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    if (descuentoActivo) ...[
                      Text(
                        'Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: Colors.grey.shade400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Text(
                      'Bs. ${precioFinal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: const Color(0xFFC026D3), // Fuchsia
                      ),
                    ),
                  ],
                ),
                if (producto.colores != null && (producto.colores as List).isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  SizedBox(
                    height: 12,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: (producto.colores as List).length,
                      separatorBuilder: (_, __) => SizedBox(width: 4.w),
                      itemBuilder: (context, index) {
                        final colorData = (producto.colores as List)[index];
                        Color color;
                        try {
                          if (colorData is Map && colorData['value'] != null) {
                             color = Color(int.parse(colorData['value'].toString().replaceFirst('#', '0xFF')));
                          } else if (colorData is String) {
                             color = Color(int.parse(colorData.replaceFirst('#', '0xFF')));
                          } else {
                             color = Colors.grey;
                          }
                        } catch (e) {
                          color = Colors.grey;
                        }
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12, width: 0.5),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
