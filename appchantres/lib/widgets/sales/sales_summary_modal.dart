import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';
import 'package:dio/dio.dart';
import '../../api.dart';
import '../../models/cliente.dart';

class SalesSummaryModal extends StatefulWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> carrito;
  final Cliente? clienteActual;
  final bool initialNoReceipt;
  final TextEditingController ciController;
  final TextEditingController nombreClienteController;
  final TextEditingController montoEntregadoController;
  
  final double Function() calcularTotalCallback;
  final Function(bool) onNoReceiptChanged;
  final Function() onBuscarCliente;
  final Function(String) onMontoEntregadoChanged;
  final Future<void> Function() onConfirmarVenta;
  final Function({bool cerrarModal}) onCancelarVenta;
  final Function(Map<String, dynamic> item, int nuevaCantidad) onItemCantidadChanged;
  final Function(Map<String, dynamic> item) onEliminarItem;

  final double initialMontoEntregado;
  final double initialCambio;
  final bool isSaving;
  final Function(double gemas, String tipoPago, double montoQR, int? idUsuarioPersonal, double descuentoPersonal, String? nombrePersonal) onVentaDetailsChanged;

  // Colores Premium
  static const Color primaryColor = Color(0xFFC026D3);
  static const Color secondaryColor = Color(0xFFE879F9);
  static const Color darkPurple = Color(0xFF701A75);

  const SalesSummaryModal({
    Key? key,
    required this.scrollController,
    required this.carrito,
    this.clienteActual,
    required this.initialNoReceipt,
    required this.ciController,
    required this.nombreClienteController,
    required this.montoEntregadoController,
    required this.calcularTotalCallback,
    required this.onNoReceiptChanged,
    required this.onBuscarCliente,
    required this.onMontoEntregadoChanged,
    required this.onConfirmarVenta,
    required this.onCancelarVenta,
    required this.onItemCantidadChanged,
    required this.onEliminarItem,
    required this.initialMontoEntregado,
    required this.initialCambio,
    required this.isSaving,
    required this.onVentaDetailsChanged,
  }) : super(key: key);

  @override
  _SalesSummaryModalState createState() => _SalesSummaryModalState();
}

class _SalesSummaryModalState extends State<SalesSummaryModal> {
  late bool _noReceipt;
  late double _montoEntregado;
  late double _cambio;
  double _gemas = 0.0;
  String _tipoPago = 'efectivo'; // 'efectivo', 'qr', 'mixto'
  double _montoQR = 0.0;
  bool _esVentaPersonal = false;
  int? _idUsuarioPersonal;
  double _descuentoPersonal = 0.0;
  List<dynamic> _usuarios = [];
  bool _loadingUsuarios = false;
  // Paso 1 = cliente + resumen + [Cobrar →]. Paso 2 = gemas/personal/método + [Cobrar ✓].
  int _paso = 1;
  
  final TextEditingController _gemasController = TextEditingController();
  final TextEditingController _montoQRController = TextEditingController();
  final TextEditingController _descuentoPersonalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _noReceipt = widget.initialNoReceipt;
    _montoEntregado = widget.initialMontoEntregado;
    _cambio = widget.initialCambio;
    widget.montoEntregadoController.text = _montoEntregado > 0 ? _montoEntregado.toStringAsFixed(2) : "";
    _fetchUsuarios();
  }

  Future<void> _fetchUsuarios() async {
    setState(() => _loadingUsuarios = true);
    try {
      final dio = Dio();
      final response = await dio.get('$BASE_URL/usuarios');
      if (mounted) {
        setState(() {
          _usuarios = response.data;
          _loadingUsuarios = false;
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
      if (mounted) setState(() => _loadingUsuarios = false);
    }
  }

  void _actualizarCambioLocal(String value) {
    double monto = double.tryParse(value) ?? 0.0;
    
    // Si estamos en mixto y el usuario está escribiendo el efectivo,
    // autocalculamos cuánto falta en QR y rellenamos la caja.
    if (_tipoPago == 'mixto') {
      double totalVenta = widget.calcularTotalCallback();
      double montoDescuentoPersonal = 0.0;
      if (_esVentaPersonal && _descuentoPersonal > 0) {
        double porcentajeSeguro = _descuentoPersonal > 100 ? 100 : _descuentoPersonal;
        montoDescuentoPersonal = (totalVenta * porcentajeSeguro) / 100;
      }
      double totalAPagar = totalVenta - _gemas - montoDescuentoPersonal;
      if (totalAPagar < 0) totalAPagar = 0;
      
      double restante = totalAPagar - monto;
      if (restante < 0) restante = 0;
      
      _montoQR = restante;
      
      // Actualizamos el textfield sin desencadenar su propio onChange
      if (_montoQRController.text != (restante > 0 ? restante.toStringAsFixed(2) : "")) {
         _montoQRController.text = restante > 0 ? restante.toStringAsFixed(2) : "";
      }
    }
    
    setState(() {
      _montoEntregado = monto;
      _updateFinancials();
    });
    widget.onMontoEntregadoChanged(value);
  }

  void _updateFinancials() {
    double totalVenta = widget.calcularTotalCallback();
    
    // El descuento de personal ahora es un porcentaje
    double montoDescuentoPersonal = 0.0;
    if (_esVentaPersonal && _descuentoPersonal > 0) {
      // Limitar descuento máximo al 100%
      double porcentajeSeguro = _descuentoPersonal > 100 ? 100 : _descuentoPersonal;
      montoDescuentoPersonal = (totalVenta * porcentajeSeguro) / 100;
    }
    
    double totalAPagar = totalVenta - _gemas - montoDescuentoPersonal;
    if (totalAPagar < 0) totalAPagar = 0;

    if (_tipoPago == 'efectivo') {
      _cambio = _montoEntregado >= totalAPagar ? _montoEntregado - totalAPagar : 0.0;
      _montoQR = 0.0;
    } else if (_tipoPago == 'qr') {
      _montoQR = totalAPagar;
      _cambio = 0.0;
      _montoEntregado = 0.0;
    } else if (_tipoPago == 'mixto') {
      double restante = totalAPagar - _montoQR;
      _cambio = _montoEntregado >= restante ? _montoEntregado - restante : 0.0;
    }
    
    String? nombreUsuarioPersonal;
    if (_idUsuarioPersonal != null) {
      final user = _usuarios.firstWhere((u) => u['id'] == _idUsuarioPersonal, orElse: () => null);
      if (user != null) {
        nombreUsuarioPersonal = user['nombre'];
      }
    }
    
    widget.onVentaDetailsChanged(_gemas, _tipoPago, _montoQR, _idUsuarioPersonal, montoDescuentoPersonal, nombreUsuarioPersonal);
  }

  void _actualizarGemas(double value) {
    setState(() {
      _gemas = value;
      _gemasController.text = _gemas > 0 ? _gemas.toStringAsFixed(0) : "";
      _updateFinancials();
    });
  }

  void _actualizarMontoQR(String value) {
    double monto = double.tryParse(value) ?? 0.0;
    
    // Si estamos en mixto y el usuario está escribiendo el QR,
    // autocalculamos cuánto falta en efectivo y rellenamos la caja.
    if (_tipoPago == 'mixto') {
      double totalVenta = widget.calcularTotalCallback();
      double montoDescuentoPersonal = 0.0;
      if (_esVentaPersonal && _descuentoPersonal > 0) {
        double porcentajeSeguro = _descuentoPersonal > 100 ? 100 : _descuentoPersonal;
        montoDescuentoPersonal = (totalVenta * porcentajeSeguro) / 100;
      }
      double totalAPagar = totalVenta - _gemas - montoDescuentoPersonal;
      if (totalAPagar < 0) totalAPagar = 0;
      
      double restante = totalAPagar - monto;
      if (restante < 0) restante = 0;
      
      _montoEntregado = restante;
      
      // Actualizamos el textfield de efectivo
      if (widget.montoEntregadoController.text != (restante > 0 ? restante.toStringAsFixed(2) : "")) {
         widget.montoEntregadoController.text = restante > 0 ? restante.toStringAsFixed(2) : "";
         widget.onMontoEntregadoChanged(widget.montoEntregadoController.text);
      }
    }
    
    setState(() {
      _montoQR = monto;
      _updateFinancials();
    });
  }

  void _toggleNoReceipt(bool? value) {
    if (value != null) {
      setState(() {
        _noReceipt = value;
      });
      widget.onNoReceiptChanged(value);
    }
  }
  
  void _confirmarEliminarProductoLocal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmar eliminación', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar ${item['nombre']} del carrito?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onEliminarItem(item);
              setState(() {}); 
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 15.h),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            _paso == 1 ? "Resumen de la Venta" : "Cobro",
            style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.bold, color: SalesSummaryModal.darkPurple),
          ),
          SizedBox(height: 4.h),
          // Indicador de paso
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPasoDot(1),
              SizedBox(width: 6.w),
              _buildPasoDot(2),
              SizedBox(width: 8.w),
              Text(
                _paso == 1 ? "Paso 1 de 2 · Cliente" : "Paso 2 de 2 · Cobro",
                style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey[500]),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: _paso == 1 ? _buildPasoCliente() : _buildPasoCobro(),
            ),
          ),
          SizedBox(height: 15.h),

          // Fixed Payment and Total Area
          _buildTotalWithDiscount(),
          SizedBox(height: 12.h),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPasoDot(int n) {
    final activo = _paso == n;
    final hecho = _paso > n;
    return Container(
      width: 22.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: activo || hecho
            ? SalesSummaryModal.primaryColor
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  /// Paso 1: cliente (si hay) + resumen del carrito + botón Cobrar.
  Widget _buildPasoCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(LineIcons.user, "Datos del Cliente"),
        SizedBox(height: 10.h),
        Row(
          children: [
            Checkbox(
              value: _noReceipt,
              onChanged: _toggleNoReceipt,
              activeColor: SalesSummaryModal.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            Text("Sin datos de recibo", style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey[700])),
          ],
        ),
        if (!_noReceipt) ...[
          _buildTextField(
            controller: widget.ciController,
            label: "CI / NIT",
            icon: LineIcons.identificationBadge,
            keyboardType: TextInputType.number,
            suffixIcon: IconButton(
              icon: const Icon(LineIcons.search, color: SalesSummaryModal.primaryColor),
              onPressed: widget.onBuscarCliente,
            ),
          ),
          SizedBox(height: 12.h),
          _buildTextField(
            controller: widget.nombreClienteController,
            label: "Nombre Completo",
            icon: LineIcons.userEdit,
            enabled: !_noReceipt,
          ),
        ],
        SizedBox(height: 20.h),
        _buildSectionHeader(LineIcons.shoppingBag, "Resumen de Compras"),
        SizedBox(height: 10.h),
        ...widget.carrito.asMap().entries.map((entry) => _buildCompactResumenProductoCard(entry.value, entry.key)).toList(),
        SizedBox(height: 10.h),
      ],
    );
  }

  /// Paso 2: gemas + venta personal + método de pago + botón Cobrar.
  Widget _buildPasoCobro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(LineIcons.userShield, "Venta a Personal"),
        SizedBox(height: 10.h),
        SwitchListTile(
          title: Text("¿Es venta a personal?", style: GoogleFonts.poppins(fontSize: 13.sp)),
          value: _esVentaPersonal,
          activeColor: SalesSummaryModal.primaryColor,
          onChanged: (val) {
            setState(() {
              _esVentaPersonal = val;
              if (!val) {
                _idUsuarioPersonal = null;
                _descuentoPersonal = 0.0;
                _descuentoPersonalController.clear();
              }
              _updateFinancials();
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_esVentaPersonal) ...[
          SizedBox(height: 10.h),
          _loadingUsuarios
            ? const Center(child: CircularProgressIndicator())
            : Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _idUsuarioPersonal,
                    hint: Text("Seleccionar Personal", style: GoogleFonts.poppins(fontSize: 13.sp)),
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    isExpanded: true,
                    items: _usuarios.map((u) {
                      return DropdownMenuItem<int>(
                        value: u['id'],
                        child: Text(u['nombre'], style: GoogleFonts.poppins(fontSize: 13.sp)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _idUsuarioPersonal = val;
                        _updateFinancials();
                      });
                    },
                  ),
                ),
              ),
          SizedBox(height: 12.h),
          _buildTextField(
            controller: _descuentoPersonalController,
            label: "Descuento Personal (%)",
            icon: LineIcons.percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixIcon: Padding(
              padding: EdgeInsets.all(12.w),
              child: Text('%', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14.sp)),
            ),
            onChanged: (val) {
              setState(() {
                _descuentoPersonal = double.tryParse(val) ?? 0.0;
                _updateFinancials();
              });
            },
          ),
        ],
        SizedBox(height: 20.h),
        _buildSectionHeader(LineIcons.coins, "Descuentos (Gemas)"),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _gemasController,
                label: "Monto en Gemas",
                icon: LineIcons.gem,
                keyboardType: TextInputType.number,
                onChanged: (val) => _actualizarGemas(double.tryParse(val) ?? 0.0),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [1, 5, 10, 20].map((val) => ActionChip(
            label: Text("Bs. $val"),
            onPressed: () => _actualizarGemas(val.toDouble()),
            backgroundColor: _gemas == val.toDouble() ? SalesSummaryModal.primaryColor : Colors.grey[100],
            labelStyle: GoogleFonts.poppins(color: _gemas == val.toDouble() ? Colors.white : Colors.grey[700], fontSize: 11.sp),
          )).toList(),
        ),
        SizedBox(height: 20.h),
        _buildSectionHeader(LineIcons.wallet, "Método de Pago"),
        SizedBox(height: 10.h),
        Row(
          children: [
            _buildPaymentTypeOption('efectivo', LineIcons.moneyBill, 'Efectivo'),
            SizedBox(width: 8.w),
            _buildPaymentTypeOption('qr', LineIcons.qrcode, 'QR'),
            SizedBox(width: 8.w),
            _buildPaymentTypeOption('mixto', LineIcons.random, 'Mixto'),
          ],
        ),
        SizedBox(height: 15.h),
        if (_tipoPago == 'efectivo' || _tipoPago == 'mixto')
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: widget.montoEntregadoController,
                  label: _tipoPago == 'mixto' ? "Efectivo Recibido" : "Efectivo",
                  icon: LineIcons.moneyBill,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _actualizarCambioLocal,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Column(
                    children: [
                      Text("Cambio", style: GoogleFonts.poppins(fontSize: 9.sp, color: Colors.green[700], fontWeight: FontWeight.w600)),
                      Text(
                        "Bs. ${_cambio.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (_tipoPago == 'mixto') ...[
          SizedBox(height: 12.h),
          _buildTextField(
            controller: _montoQRController,
            label: "Monto QR",
            icon: LineIcons.qrcode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _actualizarMontoQR,
          ),
        ],
        if (_tipoPago == 'qr')
           Container(
             width: double.infinity,
             padding: EdgeInsets.all(16.w),
             decoration: BoxDecoration(
               color: Colors.blue[50],
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Colors.blue[100]!),
             ),
             child: Column(
               children: [
                 Icon(LineIcons.qrcode, color: Colors.blue[700], size: 32),
                 SizedBox(height: 8.h),
                 Text("Pago Total por QR", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                 Text("Bs. ${(widget.calcularTotalCallback() - _gemas).toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue[700])),
               ],
             ),
           ),
        SizedBox(height: 10.h),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SalesSummaryModal.primaryColor),
        SizedBox(width: 8.w),
        Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: SalesSummaryModal.secondaryColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SalesSummaryModal.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildTotalWithDiscount() {
    double subtotal = widget.calcularTotalCallback();
    
    double montoDescuentoPersonal = 0.0;
    if (_esVentaPersonal && _descuentoPersonal > 0) {
      double porcentajeSeguro = _descuentoPersonal > 100 ? 100 : _descuentoPersonal;
      montoDescuentoPersonal = (subtotal * porcentajeSeguro) / 100;
    }
    
    double total = subtotal - _gemas - montoDescuentoPersonal;
    if (total < 0) total = 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SalesSummaryModal.darkPurple, SalesSummaryModal.primaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: SalesSummaryModal.primaryColor.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          if (_gemas > 0)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SUBTOTAL", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10.sp)),
                  Text("Bs. ${subtotal.toStringAsFixed(2)}", style: GoogleFonts.poppins(color: Colors.white70, decoration: TextDecoration.lineThrough, fontSize: 10.sp)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL A PAGAR",
                style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
              Text(
                "Bs. ${total.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeOption(String type, IconData icon, String label) {
    bool isSelected = _tipoPago == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tipoPago = type;
            _updateFinancials();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? SalesSummaryModal.primaryColor : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? SalesSummaryModal.primaryColor : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
              SizedBox(height: 4.h),
              Text(label, style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.grey[600], fontSize: 10.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_paso == 1) {
      // Paso 1: cerrar o pasar al cobro (valida carrito no vacío).
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => widget.onCancelarVenta(cerrarModal: true),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15.h),
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Cerrar", style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: widget.carrito.isEmpty
                  ? null
                  : () => setState(() => _paso = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: SalesSummaryModal.primaryColor,
                padding: EdgeInsets.symmetric(vertical: 15.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Cobrar", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
                  SizedBox(width: 6.w),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      );
    }
    // Paso 2: atrás o confirmar cobro.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.isSaving ? null : () => setState(() => _paso = 1),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15.h),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back, color: Colors.grey, size: 18),
                SizedBox(width: 4.w),
                Text("Atrás", style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: widget.isSaving ? null : widget.onConfirmarVenta,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E), // Success Green
              padding: EdgeInsets.symmetric(vertical: 15.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: widget.isSaving 
              ? SpinKitThreeBounce(color: Colors.white, size: 20.sp)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 6.w),
                    Text("Cobrar", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactResumenProductoCard(Map<String, dynamic> item, int index) {
    String imageUrl = item['imagen'] != null && item['imagen'].isNotEmpty
        ? "$BASE_URL${item['imagen']}"
        : "";

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 50.w,
                    height: 50.w,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100]),
                  )
                : Container(color: Colors.grey[100], width: 50.w, height: 50.w, child: Icon(LineIcons.image, color: Colors.grey[300])),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nombre'] ?? 'Producto',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.sp, color: Colors.grey[800]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Bs. ${(item['precio_venta'] ?? 0.0).toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(fontSize: 12.sp, color: SalesSummaryModal.primaryColor, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      height: 30.h,
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: item['cantidad'] ?? 1,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
                        items: List.generate(item['stock'] ?? 1, (i) => i + 1)
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text("$e", style: GoogleFonts.poppins(fontSize: 12.sp)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                             widget.onItemCantidadChanged(item, value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LineIcons.trash, color: Colors.red[300], size: 22),
            onPressed: () => _confirmarEliminarProductoLocal(item),
          ),
        ],
      ),
    );
  }
}
