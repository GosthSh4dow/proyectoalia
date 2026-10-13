import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../api.dart';
import 'package:dio/dio.dart';
import '../servicios/api_service.dart';

/// Resultado del panel de escaneo múltiple
class ScanPanelResult {
  final List<String> codes;
  final int? sucursalId;
  final Map<String, dynamic>? sucursal;

  ScanPanelResult({
    required this.codes,
    this.sucursalId,
    this.sucursal,
  });
}

/// Panel de escaneo múltiple: escanea códigos continuamente sin cortar,
/// permite seleccionar sucursal y terminar para devolver todos los códigos.
class ScanPanelScreen extends StatefulWidget {
  /// Sucursales disponibles para seleccionar (opcional, se usan las del provider si no se pasan)
  final List<dynamic>? sucursales;
  /// Sucursal seleccionada inicialmente (opcional)
  final int? initialSucursalId;
  /// Mensaje de instrucción en la parte inferior
  final String? hintMessage;
  /// Si true, no muestra selector de sucursales
  final bool hideBranchSelector;

  const ScanPanelScreen({
    Key? key,
    this.sucursales,
    this.initialSucursalId,
    this.hintMessage,
    this.hideBranchSelector = false,
  }) : super(key: key);

  @override
  State<ScanPanelScreen> createState() => _ScanPanelScreenState();
}

class _ScanPanelScreenState extends State<ScanPanelScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  final List<String> _scannedCodes = [];
  final Set<String> _scannedSet = {};

  bool _scannerActivo = false;
  bool _isLoadingSucursales = false;
  List<dynamic> _sucursales = [];
  int? _selectedSucursalId;
  Map<String, dynamic>? _selectedSucursal;

  @override
  void initState() {
    super.initState();
    _initSucursales();
  }

  Future<void> _initSucursales() async {
    // Usar sucursales pasadas por parámetro o del provider
    final userProvider = context.read<UserProvider>();
    List<dynamic> suc = widget.sucursales ?? userProvider.sucursales;

    if (suc.isEmpty) {
      // Cargar desde API si no hay ninguna
      setState(() => _isLoadingSucursales = true);
      try {
        final r = await ApiService().dio.get(getApiUrl('sucursales'));
        suc = r.data as List;
      } catch (_) {}
      setState(() => _isLoadingSucursales = false);
    }

    setState(() {
      _sucursales = suc;
      _selectedSucursalId = widget.initialSucursalId ?? userProvider.branchId;
      // Buscar la sucursal seleccionada
      if (_selectedSucursalId != null) {
        final found = _sucursales.firstWhere(
          (s) => s['id'] == _selectedSucursalId,
          orElse: () => null,
        );
        if (found != null) {
          _selectedSucursal = found;
        }
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    // Evitar duplicados
    if (_scannedSet.contains(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Código ya escaneado: $code',
              style: GoogleFonts.poppins(fontSize: 13.sp)),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(milliseconds: 800),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _scannedCodes.add(code);
      _scannedSet.add(code);
    });
  }

  void _removeCode(int index) {
    setState(() {
      _scannedSet.remove(_scannedCodes[index]);
      _scannedCodes.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _scannedCodes.clear();
      _scannedSet.clear();
    });
  }

  void _terminar() {
    Navigator.of(context).pop(
      ScanPanelResult(
        codes: List<String>.from(_scannedCodes),
        sucursalId: _selectedSucursalId,
        sucursal: _selectedSucursal,
      ),
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFC026D3); // Fuchsia-600
    final secondaryColor = const Color(0xFFE879F9); // Fuchsia-400

    return Scaffold(
      backgroundColor: const Color(0xFFFDF4FF),
      appBar: AppBar(
        title: Text(
          'Panel de Escaneo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_scannedCodes.isNotEmpty)
            IconButton(
              icon: const Icon(LineIcons.trash, color: Colors.white70),
              onPressed: _clearAll,
              tooltip: 'Limpiar todos',
            ),
        ],
      ),
      body: Column(
        children: [
          // Selector de sucursal
          if (!widget.hideBranchSelector)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              color: Colors.white,
              child: _isLoadingSucursales
                  ? Row(
                      children: [
                        SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text('Cargando sucursales...',
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 13.sp)),
                      ],
                    )
                  : _sucursales.isEmpty
                      ? Text('No hay sucursales disponibles',
                          style: GoogleFonts.poppins(
                              color: Colors.grey, fontSize: 13.sp))
                      : DropdownButtonFormField<int>(
                          value: _selectedSucursalId,
                          decoration: InputDecoration(
                            labelText: 'Sucursal',
                            labelStyle: GoogleFonts.poppins(
                                color: Colors.grey.shade600, fontSize: 13.sp),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 8.h),
                          ),
                          items: _sucursales.map<DropdownMenuItem<int>>((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text(
                                s['nombre'] ?? 'Sin nombre',
                                style: GoogleFonts.poppins(fontSize: 14.sp),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (int? value) {
                            setState(() {
                              _selectedSucursalId = value;
                              if (value != null) {
                                final found = _sucursales.firstWhere(
                                  (s) => s['id'] == value,
                                  orElse: () => null,
                                );
                                _selectedSucursal = found;
                              }
                            });
                          },
                        ),
            ),

          // Toggle escáner
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: GestureDetector(
              onTap: () => setState(() {
                _scannerActivo = !_scannerActivo;
                if (!_scannerActivo) _scanner.stop();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: _scannerActivo
                      ? Colors.red.withOpacity(0.08)
                      : primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _scannerActivo ? Colors.red : primaryColor,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _scannerActivo ? LineIcons.stop : LineIcons.camera,
                      color: _scannerActivo ? Colors.red : primaryColor,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      _scannerActivo ? 'DETENER ESCÁNER' : 'ACTIVAR CÁMARA',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: _scannerActivo ? Colors.red : primaryColor,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Visor de cámara
          if (_scannerActivo)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                height: 160.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: primaryColor, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: MobileScanner(
                    controller: _scanner,
                    onDetect: _onDetect,
                  ),
                ),
              ),
            ),

          // Instrucción
          if (!_scannerActivo)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(LineIcons.info, color: Colors.grey.shade600, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        widget.hintMessage ??
                            'Activa la cámara y enfoca los códigos de barras. '
                                'Los códigos se añadirán automáticamente.',
                        style: GoogleFonts.poppins(
                            color: Colors.grey.shade700, fontSize: 12.5.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lista de códigos escaneados
          Expanded(
            child: _scannedCodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LineIcons.barcode,
                          size: 56.sp,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Esperando escaneos...',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    itemCount: _scannedCodes.length,
                    itemBuilder: (_, i) => Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                            color: primaryColor.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LineIcons.barcode,
                              color: primaryColor,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              _scannedCodes[i],
                              style: GoogleFonts.robotoMono(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '#${i + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: () => _removeCode(i),
                            child: Icon(
                              LineIcons.times,
                              color: Colors.red.shade400,
                              size: 20.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Botón Terminar
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 6,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                icon: const Icon(LineIcons.check, color: Colors.white),
                label: Text(
                  'TERMINAR (${_scannedCodes.length})',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                    color: Colors.white,
                  ),
                ),
                onPressed: _scannedCodes.isNotEmpty ? _terminar : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
