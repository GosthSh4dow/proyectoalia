import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';

class InventoryHeader extends StatelessWidget {
  final List<dynamic> sucursales;
  final int? selectedSucursalId;
  final List<dynamic> pedidosRecibidos;
  final int? selectedPedidoId;
  final Function(int?) onSucursalChanged;
  final Function(int?) onPedidoChanged;

  const InventoryHeader({
    Key? key,
    required this.sucursales,
    required this.selectedSucursalId,
    required this.pedidosRecibidos,
    required this.selectedPedidoId,
    required this.onSucursalChanged,
    required this.onPedidoChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          _buildElegantDropdown(
            label: "SUCURSAL DESTINO",
            icon: LineIcons.store,
            items: sucursales,
            value: selectedSucursalId,
            onChanged: onSucursalChanged,
            hint: "Seleccionar sucursal...",
          ),
          SizedBox(height: 16.h),
          _buildElegantDropdown(
            label: "ORDEN DE COMPRA RECIBIDA",
            icon: LineIcons.fileInvoice,
            items: pedidosRecibidos,
            value: selectedPedidoId,
            onChanged: onPedidoChanged,
            isPedido: true,
            hint: "Seleccionar pedido...",
          ),
        ],
      ),
    );
  }

  Widget _buildElegantDropdown({
    required String label,
    required IconData icon,
    required List<dynamic> items,
    required int? value,
    required Function(int?) onChanged,
    required String hint,
    bool isPedido = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFC026D3).withOpacity(0.6),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF4FF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE879F9).withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey)),
              icon: Icon(LineIcons.chevronCircleDown, color: const Color(0xFFC026D3), size: 20.sp),
              items: items.map<DropdownMenuItem<int>>((item) {
                return DropdownMenuItem<int>(
                  value: item['id'],
                  child: Row(
                    children: [
                      Icon(icon, size: 18.sp, color: const Color(0xFFC026D3)),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          isPedido ? "Pedido: ${item['codigo']}" : item['nombre'],
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
