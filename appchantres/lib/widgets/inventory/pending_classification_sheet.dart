import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';

class PendingClassificationSheet extends StatelessWidget {
  final String barcode;
  final List<dynamic> productosPendientes;
  final Function(dynamic) onSelected;

  const PendingClassificationSheet({
    Key? key,
    required this.barcode,
    required this.productosPendientes,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CLASIFICACIÓN REQUERIDA",
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC026D3),
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Código: $barcode",
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LineIcons.times, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            "Selecciona a qué producto del pedido corresponde este código de barras:",
            style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          SizedBox(height: 20.h),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: productosPendientes.length,
              itemBuilder: (context, index) {
                final p = productosPendientes[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: InkWell(
                    onTap: () => onSelected(p),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF4FF),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFE879F9).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(LineIcons.box, color: const Color(0xFFC026D3), size: 24.sp),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['nombre'] ?? 'Sin nombre',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "ID Temp: ${p['id']} | Cantidad: ${p['stock']}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(LineIcons.chevronCircleRight, color: const Color(0xFFC026D3), size: 18.sp),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
