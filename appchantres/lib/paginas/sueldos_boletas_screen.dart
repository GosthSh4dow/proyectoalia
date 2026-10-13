import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:line_icons/line_icons.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';


import '../servicios/sueldos_service.dart';
import '../widgets/animated_empty_state.dart'; 

class SueldosBoletasScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const SueldosBoletasScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _SueldosBoletasScreenState createState() => _SueldosBoletasScreenState();
}

class _SueldosBoletasScreenState extends State<SueldosBoletasScreen> {
  final SueldosService _sueldosService = SueldosService();
  
  // Data
  List<dynamic> _empleados = [];
  List<dynamic> _boletasPago = [];
  List<dynamic> _asistencias = [];
  Map<String, dynamic>? _empleadoSeleccionado;
  
  // State
  bool _loading = false;
  bool _loadingAsistencias = false;
  double _montoTurno = 50.0;
  double _totalSueldo = 0;
  Map<String, dynamic> _resumen = {};
  List<Map<String, dynamic>> _detalles = [];
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Colors
  final Color _primaryColor = const Color(0xFFC026D3);
  final Color _secondaryColor = const Color(0xFFE879F9);
  final Color _backgroundColor = const Color(0xFFFDF4FF);
  
  // Editing State
  Map<String, dynamic>? _asistenciaEditada;
  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();
  String _selectedEstado = 'Asistido';
  String? _selectedJustificacion;
  dynamic _selectedReemplazo;
  bool _isEditing = false;
  final TextEditingController _montoController = TextEditingController(text: "50");

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _montoController.addListener(() {
      _handleMontoTurnoChange(_montoController.text);
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final empleados = await _sueldosService.obtenerEmpleados();
      final boletas = await _sueldosService.obtenerBoletas();
      if (!mounted) return;
      setState(() {
        _empleados = empleados;
        _boletasPago = boletas;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al cargar datos: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAsistencias(String empleadoId) async {
    if (!mounted) return;
    setState(() => _loadingAsistencias = true);
    try {
      // Find last payment date to filter asistencias
      String? lastPaymentDate;
      if (_boletasPago.isNotEmpty) {
        final boletasEmpleado = _boletasPago.where((b) => 
          b['id_usuario'].toString() == empleadoId
        ).toList();
        
        if (boletasEmpleado.isNotEmpty) {
          boletasEmpleado.sort((a, b) => 
            DateTime.parse(a['fecha_pago']).compareTo(DateTime.parse(b['fecha_pago']))
          );
          lastPaymentDate = boletasEmpleado.last['fecha_pago'];
        }
      }

      final asistencias = await _sueldosService.obtenerAsistencias(
        empleadoId, 
        fechaPago: lastPaymentDate
      );
      
      if (!mounted) return;
      
      // Determinar periodo sugerido
      DateTime hoy = DateTime.now();
      DateTime inicio = hoy.subtract(const Duration(days: 30)); // Default fallback
      
      if (lastPaymentDate != null) {
        DateTime lastDate = DateTime.parse(lastPaymentDate);
        inicio = lastDate.add(const Duration(days: 1));
      } else if (asistencias.isNotEmpty) {
        asistencias.sort((a, b) => DateTime.parse(a['fecha']).compareTo(DateTime.parse(b['fecha'])));
        inicio = DateTime.parse(asistencias.first['fecha']);
      }

      // Seguridad: el inicio nunca puede ser después de hoy (evita el error del screenshot)
      if (inicio.isAfter(hoy)) {
        inicio = hoy;
      }

      setState(() {
        _asistencias = asistencias;
        _fechaInicio = inicio;
        _fechaFin = hoy;
      });
      _calcularTotalSueldo();
      
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al cargar asistencias: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingAsistencias = false);
    }
  }

  void _handleSeleccionarEmpleado(dynamic empleado) {
    setState(() {
      _empleadoSeleccionado = empleado;
      _asistencias = [];
      _resumen = {};
    });
    if (empleado != null) {
      _fetchAsistencias(empleado['id'].toString());
    }
  }

  void _handleMontoTurnoChange(String value) {
    double nuevoMonto = double.tryParse(value) ?? 0;
    setState(() {
      _montoTurno = nuevoMonto;
    });
    _calcularTotalSueldo();
  }

  void _calcularTotalSueldo() {
    if (_empleadoSeleccionado == null) return;

    int asistenciasCount = 0;
    int reemplazosCount = 0;
    int faltasInjustificadas = 0;
    int faltasJustificadas = 0;

    for (var item in _asistencias) {
      final estado = item['estado'];
      if (estado == "Asistido") {
        asistenciasCount++;
      } else if (estado == "Reemplazo") {
        reemplazosCount++;
      } else if (estado == "Falta") {
        if (item['justificado'] == 1) {
          faltasJustificadas++;
        } else {
          faltasInjustificadas++;
        }
      }
    }

    double total = (asistenciasCount + reemplazosCount) * _montoTurno;
    
    // Sumar incentivos y restar descuentos
    for (var d in _detalles) {
      if (d['tipo'] == 'Incentivo') {
        total += d['monto'];
      } else {
        total -= d['monto'];
      }
    }
    
    if (mounted) {
      setState(() {
        _totalSueldo = total;
        _resumen = {
          'asistenciasCount': asistenciasCount,
          'reemplazosCount': reemplazosCount,
          'faltasJustificadas': faltasJustificadas,
          'faltasInjustificadas': faltasInjustificadas,
          'totalSueldo': total,
        };
      });
    }
  }

  void _handleGenerarBoleta() async {
    if (_empleadoSeleccionado == null) {
      _showSnackBar('Seleccione un empleado', isError: true);
      return;
    }
    
    _detalles = [];
    _calcularTotalSueldo();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            insetPadding: EdgeInsets.all(15.w),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(LineIcons.fileInvoiceWithUsDollar, color: Colors.white),
                  SizedBox(width: 12.w),
                  Text(
                    'Generar Boleta', 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18.sp)
                  ),
                ],
              ),
            ),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INFORMACIÓN GENERAL', style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 1)),
                    SizedBox(height: 8.h),
                    _buildSummaryRow('Empleado:', _empleadoSeleccionado!['nombre']),
                    _buildSummaryRow('Desde:', _fechaInicio != null ? DateFormat('dd/MM/yyyy').format(_fechaInicio!) : '--'),
                    _buildSummaryRow('Hasta:', _fechaFin != null ? DateFormat('dd/MM/yyyy').format(_fechaFin!) : '--'),
                    _buildSummaryRow('Asistencias:', '${_resumen['asistenciasCount']}'),
                    _buildSummaryRow('Reemplazos:', '${_resumen['reemplazosCount']}'),
                    
                    const Divider(height: 30),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CONCEPTOS ADICIONALES', style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text('${_detalles.length}', style: GoogleFonts.poppins(fontSize: 10.sp, color: _primaryColor, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_detalles.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('No hay incentivos ni descuentos', style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey[400], fontStyle: FontStyle.italic)),
                        ),
                      )
                    else
                      ..._detalles.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Map<String, dynamic> detalle = entry.value;
                        bool isIncentivo = detalle['tipo'] == 'Incentivo';
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: isIncentivo ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (isIncentivo ? Colors.green : Colors.red).withOpacity(0.1))
                          ),
                          child: Row(
                            children: [
                              Icon(isIncentivo ? LineIcons.plusCircle : LineIcons.minusCircle, color: isIncentivo ? Colors.green : Colors.red, size: 20),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(detalle['nombre'], style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                                    Text(detalle['tipo'], style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncentivo ? '+' : '-'} Bs. ${detalle['monto']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: isIncentivo ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    _detalles.removeAt(idx);
                                  });
                                  _calcularTotalSueldo();
                                  setDialogState(() {});
                                },
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _mostrarDialogoAgregarDetalle(setDialogState, 'Incentivo'),
                            icon: const Icon(LineIcons.plus, size: 16),
                            label: Text('Incentivo', style: GoogleFonts.poppins(fontSize: 11.sp)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(vertical: 10.h)
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _mostrarDialogoAgregarDetalle(setDialogState, 'Descuento'),
                            icon: const Icon(LineIcons.minus, size: 16),
                            label: Text('Descuento', style: GoogleFonts.poppins(fontSize: 11.sp)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(vertical: 10.h)
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primaryColor.withOpacity(0.2))
                      ),
                      child: _buildSummaryRow('TOTAL NETO A PAGAR:', 'Bs. ${_totalSueldo.toStringAsFixed(2)}', isBold: true),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmGenerarBoleta();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  minimumSize: Size(120.w, 45.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0
                ),
                child: Text('Confirmar Pago', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoAgregarDetalle(StateSetter setDialogState, String tipo) {
    final TextEditingController _nombreCtrl = TextEditingController();
    final TextEditingController _montoCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar $tipo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(labelText: 'Nombre del concepto'),
              style: GoogleFonts.poppins(),
            ),
            TextField(
              controller: _montoCtrl,
              decoration: InputDecoration(labelText: 'Monto'),
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (_nombreCtrl.text.isNotEmpty && _montoCtrl.text.isNotEmpty) {
                setDialogState(() {
                  _detalles.add({
                    'nombre': _nombreCtrl.text,
                    'monto': double.tryParse(_montoCtrl.text) ?? 0.0,
                    'tipo': tipo
                  });
                });
                _calcularTotalSueldo();
                setDialogState(() {}); // update dialog total
                Navigator.pop(context);
              }
            },
            child: Text('Agregar'),
          )
        ],
      ),
    );
  }

  Future<void> _confirmGenerarBoleta() async {
    try {
      final boletaData = {
        'id_usuario': _empleadoSeleccionado!['id'],
        'monto_turno': _montoTurno,
        'total': _totalSueldo,
        'asistencias_count': _resumen['asistenciasCount'],
        'faltas_injustificadas': _resumen['faltasInjustificadas'],
        'faltas_justificadas': _resumen['faltasJustificadas'],
        'reemplazos_count': _resumen['reemplazosCount'],
        'fecha_pago': DateTime.now().toIso8601String(),
        'fecha_inicio': _fechaInicio?.toIso8601String().split('T')[0],
        'fecha_fin': _fechaFin?.toIso8601String().split('T')[0],
        'detalles': _detalles,
      };
      
      await _sueldosService.crearBoleta(boletaData);
      
      if (!mounted) return;
      _showSnackBar('Boleta generada exitosamente');
      
      // Reload data
      final boletas = await _sueldosService.obtenerBoletas();
      if (!mounted) return;
      setState(() {
        _boletasPago = boletas;
        _detalles = []; // Clear details
        // Refresh asistencias list (should be empty now for next period)
        _fetchAsistencias(_empleadoSeleccionado!['id'].toString()); 
      });
      
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al generar boleta: $e', isError: true);
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label, 
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13.sp)
            )
          ),
          Expanded(
            flex: 3,
            child: Text(
              value, 
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isBold ? _primaryColor : Colors.black87,
                fontSize: isBold ? 16.sp : 14.sp
              )
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleGenerarPDF() async {
    if (_empleadoSeleccionado == null) {
      _showSnackBar('Seleccione un empleado para generar el PDF', isError: true);
      return;
    }

    if (_asistencias.isEmpty) {
      _showSnackBar('No hay asistencias para generar el PDF', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: SpinKitFadingCircle(color: _primaryColor, size: 50),
        );
      },
    );

    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 4);
      grid.headers.add(1);

      PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Fecha';
      header.cells[1].value = 'Estado';
      header.cells[2].value = 'Justificación';
      header.cells[3].value = 'Reemplazo';

      header.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(192, 38, 211)), // 0xFFC026D3
        textBrush: PdfBrushes.white,
        font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
      );

      for (var asistencia in _asistencias) {
        PdfGridRow row = grid.rows.add();
        row.cells[0].value = DateFormat.yMMMMd('es').format(DateTime.parse(asistencia['fecha']));
        row.cells[1].value = asistencia['estado'] ?? 'N/A';

        String justificacion = 'N/A';
        if (asistencia['estado'] == 'Falta') {
          justificacion = asistencia['justificado'] == 1 ? 'Justificada' : 'No justificada';
        }
        row.cells[2].value = justificacion;

        String reemplazo = 'N/A';
        if (asistencia['reemplazo'] != null) {
          reemplazo = asistencia['reemplazo']['nombre'] ?? 'N/A';
        }
        row.cells[3].value = reemplazo;
      }

      grid.columns[0].width = 120;
      grid.columns[1].width = 80;
      grid.columns[2].width = 100;

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 5, right: 5, top: 5, bottom: 5),
        font: PdfStandardFont(PdfFontFamily.helvetica, 9),
      );

      final PdfLayoutResult result = PdfTextElement(
        text: 'Reporte de Asistencias',
        font: PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      ).draw(
        page: page,
        bounds: const Rect.fromLTWH(0, 0, 500, 50),
      )!;

      PdfTextElement(
        text: 'Empleado: ${_empleadoSeleccionado!['nombre']}',
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, result.bounds.bottom + 10, 500, 20),
      );

      PdfTextElement(
        text: 'Fecha de impresión: ${DateFormat.yMMMMd('es').format(DateTime.now())}',
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, result.bounds.bottom + 30, 500, 20),
      );

      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, result.bounds.bottom + 60, page.getClientSize().width, page.getClientSize().height),
      );

      final List<int> bytes = await document.saveSync();
      document.dispose();

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/asistencias_${_empleadoSeleccionado!['nombre'].toString().replaceAll(' ', '_')}.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      await OpenFile.open(filePath);

      _showSnackBar('PDF de asistencias generado exitosamente');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      _showSnackBar('Error al generar PDF: $e', isError: true);
    }
  }

  Future<void> _generarBoletaPDF(dynamic boleta) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: SpinKitFadingCircle(color: _primaryColor, size: 50),
        );
      },
    );

    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final Size pageSize = page.getClientSize();

      // --- HEADER BANNER ---
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(192, 38, 211)),
        bounds: Rect.fromLTWH(0, 0, pageSize.width, 100),
      );

      PdfTextElement(
        text: 'BOLETA DE PAGO',
        font: PdfStandardFont(PdfFontFamily.helvetica, 30, style: PdfFontStyle.bold),
        brush: PdfBrushes.white,
      ).draw(page: page, bounds: const Rect.fromLTWH(25, 30, 0, 0));

      PdfTextElement(
        text: 'Channels - Gestión de Asistencia',
        font: PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfBrushes.white,
      ).draw(page: page, bounds: const Rect.fromLTWH(25, 70, 0, 0));

      // --- INFO BOX ---
      double startY = 120;
      
      PdfTextElement(
        text: 'DETALLES DEL EMPLEADO',
        font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      ).draw(page: page, bounds: Rect.fromLTWH(25, startY, 200, 20));

      // Rectángulo de fondo suave para info
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(250, 250, 250)),
        bounds: Rect.fromLTWH(25, startY + 15, pageSize.width - 50, 60),
      );

      String nombre = boleta['empleado_nombre'] ?? (boleta['usuario'] != null ? boleta['usuario']['nombre'] : 'N/A');
      String periodoStr = "N/A";
      if (boleta['fecha_inicio'] != null && boleta['fecha_fin'] != null) {
        periodoStr = "${DateFormat('dd/MM/yyyy').format(DateTime.parse(boleta['fecha_inicio']))} al ${DateFormat('dd/MM/yyyy').format(DateTime.parse(boleta['fecha_fin']))}";
      }

      PdfTextElement(text: 'NOMBRE:', font: PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold)).draw(page: page, bounds: Rect.fromLTWH(40, startY + 25, 100, 20));
      PdfTextElement(text: nombre.toUpperCase(), font: PdfStandardFont(PdfFontFamily.helvetica, 9)).draw(page: page, bounds: Rect.fromLTWH(110, startY + 25, 300, 20));

      PdfTextElement(text: 'PERIODO:', font: PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold)).draw(page: page, bounds: Rect.fromLTWH(40, startY + 45, 100, 20));
      PdfTextElement(text: periodoStr, font: PdfStandardFont(PdfFontFamily.helvetica, 9)).draw(page: page, bounds: Rect.fromLTWH(110, startY + 45, 300, 20));

      PdfTextElement(text: 'FECHA PAGO:', font: PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold)).draw(page: page, bounds: Rect.fromLTWH(pageSize.width - 180, startY + 25, 100, 20));
      PdfTextElement(text: boleta['fecha_pago'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(boleta['fecha_pago'])) : "N/A", font: PdfStandardFont(PdfFontFamily.helvetica, 9)).draw(page: page, bounds: Rect.fromLTWH(pageSize.width - 100, startY + 25, 100, 20));

      // --- TABLA DE CONCEPTOS ---
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 2);
      grid.columns[0].width = pageSize.width - 150;
      
      PdfGridRow header = grid.headers.add(1)[0];
      header.cells[0].value = 'CONCEPTO';
      header.cells[1].value = 'MONTO (BS.)';
      header.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(192, 38, 211, 20)),
        font: PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
      );

      _addPdfRow(grid, 'Turnos Trabajados (${(boleta['asistencias_count'] ?? 0) + (boleta['reemplazos_count'] ?? 0)})', '${((boleta['asistencias_count'] ?? 0) + (boleta['reemplazos_count'] ?? 0)) * (boleta['monto_turno'] ?? 0)} Bs');
      
      if (boleta['detalles'] != null && boleta['detalles'] is List) {
        for (var detalle in boleta['detalles']) {
          String prefix = detalle['tipo'] == 'Incentivo' ? '+' : '-';
          _addPdfRow(grid, detalle['nombre'] ?? 'Concepto', '$prefix ${detalle['monto']} Bs');
        }
      }

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 15, right: 15, top: 8, bottom: 8),
        font: PdfStandardFont(PdfFontFamily.helvetica, 10),
      );

      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(25, startY + 90, pageSize.width - 50, 0),
      );

      // --- TOTAL BOX ---
      double totalY = startY + 90 + (grid.rows.count * 30) + 40;
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(192, 38, 211)),
        bounds: Rect.fromLTWH(pageSize.width - 250, totalY, 225, 40),
      );

      PdfTextElement(
        text: 'TOTAL NETO:',
        font: PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
        brush: PdfBrushes.white,
      ).draw(page: page, bounds: Rect.fromLTWH(pageSize.width - 235, totalY + 12, 100, 20));

      PdfTextElement(
        text: 'Bs. ${boleta['total'] ?? 0}',
        font: PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
        brush: PdfBrushes.white,
      ).draw(page: page, bounds: Rect.fromLTWH(pageSize.width - 120, totalY + 10, 100, 20));

      // --- SIGNATURES ---
      final double bottomY = pageSize.height - 80;
      
      // Líneas de firma
      page.graphics.drawLine(PdfPens.black, Offset(50, bottomY), Offset(200, bottomY));
      page.graphics.drawLine(PdfPens.black, Offset(pageSize.width - 200, bottomY), Offset(pageSize.width - 50, bottomY));

      PdfTextElement(text: 'FIRMA EMPLEADO', font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold)).draw(
        page: page, bounds: Rect.fromLTWH(90, bottomY + 5, 200, 20));
      
      PdfTextElement(text: 'FIRMA EMPLEADOR', font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold)).draw(
        page: page, bounds: Rect.fromLTWH(pageSize.width - 165, bottomY + 5, 200, 20));

      final List<int> bytes = await document.saveSync();
      document.dispose();

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/boleta_${boleta['id']}.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      await OpenFile.open(filePath);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error al generar la boleta: $e', isError: true);
    }
  }


  void _addPdfRow(PdfGrid grid, String label, String value) {
    PdfGridRow row = grid.rows.add();
    row.cells[0].value = label;
    row.cells[1].value = value;
  }

  // -- Edit Logic --
  
  void _handleEditarAsistencia(dynamic asistencia) {
    _asistenciaEditada = asistencia;
    _selectedEstado = asistencia['estado'];
     // Check strict type for 'justificado' (backend might send Int or Boolean)
    _selectedJustificacion = (asistencia['justificado'] == 1 || asistencia['justificado'] == true) 
        ? "Justificada" : "No Justificada";
    _selectedReemplazo = asistencia['reemplazo']; 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Editar Asistencia', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Form(
          key: _editFormKey,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField2<String>(
                      value: _selectedEstado,
                      decoration: InputDecoration(
                         labelText: "Estado",
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      items: ["Asistido", "Falta", "Tardanza", "Reemplazo"]
                          .map((estado) => DropdownMenuItem(value: estado, child: Text(estado)))
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedEstado = value!;
                          if (_selectedEstado != 'Falta') _selectedJustificacion = null;
                          if (_selectedEstado != 'Reemplazo') _selectedReemplazo = null;
                        });
                      },
                      validator: (value) => value == null ? "Seleccione estado" : null,
                    ),
                    SizedBox(height: 16),
                    
                    if (_selectedEstado == "Falta")
                      DropdownButtonFormField2<String>(
                        value: _selectedJustificacion,
                        decoration: InputDecoration(
                          labelText: "Justificación",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        items: ["Justificada", "No Justificada"]
                            .map((just) => DropdownMenuItem(value: just, child: Text(just)))
                            .toList(),
                        onChanged: (value) => setStateDialog(() => _selectedJustificacion = value),
                        validator: (value) => value == null ? "Seleccione justificación" : null,
                      ),
                    
                    if (_selectedEstado == "Falta") SizedBox(height: 16),
    
                    if (_selectedEstado == "Reemplazo")
                      DropdownButtonFormField2<dynamic>(
                        value: _selectedReemplazo,
                        decoration: InputDecoration(
                          labelText: "Reemplazo",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        hint: Text("Seleccione Reemplazo", style: GoogleFonts.poppins()),
                        items: _empleados.map<DropdownMenuItem<dynamic>>((emp) {
                          return DropdownMenuItem<dynamic>(
                            value: emp,
                            child: Text(emp['nombre']),
                          );
                        }).toList(),
                        onChanged: (value) => setStateDialog(() => _selectedReemplazo = value),
                        validator: (value) => value == null ? "Seleccione un reemplazo" : null,
                      ),
                  ],
                );
              }
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_editFormKey.currentState!.validate()) {
                _updateAsistencia();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAsistencia() async {
     // Show loading or similar if needed
     Navigator.pop(context); // Close dialog first to avoid context issues with async
     
     final payload = {
      'estado': _selectedEstado,
      'justificado': _selectedEstado == "Falta" ? (_selectedJustificacion == "Justificada" ? 1 : 0) : null,
      'reemplazo': _selectedEstado == "Reemplazo" ? _selectedReemplazo['id'] : null,
    };
    
     try {
       await _sueldosService.actualizarAsistencia(_asistenciaEditada!['id'].toString(), payload);
       if (!mounted) return;
       _fetchAsistencias(_empleadoSeleccionado!['id'].toString());
       _showSnackBar('Actualizado correctamente');
     } catch(e) {
       if (!mounted) return;
       _showSnackBar('Error: $e', isError: true);
     }
  }

  Future<void> _handleEliminarAsistencia(dynamic asistencia) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('¿Está seguro de eliminar esta asistencia?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _sueldosService.eliminarAsistencia(asistencia['id'].toString());
        if (!mounted) return;
        _fetchAsistencias(_empleadoSeleccionado!['id'].toString());
        _showSnackBar('Eliminado correctamente');
      } catch(e) {
        if (!mounted) return;
        _showSnackBar('Error al eliminar: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: SizedBox(height: 20.h)),
          
          if (_loading)
            SliverFillRemaining(
              child: Center(child: SpinKitFadingCircle(color: _primaryColor, size: 50)),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEmployeeSelector(),
                    SizedBox(height: 20.h),
                    if (_empleadoSeleccionado != null) ...[
                      _buildStatsGrid(),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Asistencias',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${_asistencias.length} Registros',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildAsistenciasList(),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Boletas de Pago',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${_boletasPago.where((boleta) => boleta['id_usuario'].toString() == _empleadoSeleccionado!['id'].toString()).length} Registros',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildBoletasList(),
                    ] else 
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 100.h)),
        ],
      ),
      floatingActionButton: _empleadoSeleccionado != null ? FloatingActionButton.extended(
        onPressed: _handleGenerarBoleta,
        backgroundColor: _primaryColor,
        icon: const Icon(LineIcons.fileInvoiceWithUsDollar, color: Colors.white),
        label: Text(
          'Generar Boleta',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ) : null,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(LineIcons.bars, color: Colors.white),
          onPressed: widget.onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryColor, _secondaryColor],
                  ),
                ),
              ),
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sueldos y Boletas',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Gestión de pagos y asistencias',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
       child: Padding(
         padding: EdgeInsets.only(top: 40.h),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             AnimatedEmptyState(
                title: 'Sin Asistencias',
                message: 'Seleccione un empleado para ver detalles',
                icon: LineIcons.dropbox,
                color: _primaryColor,
             ).animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 600.ms),
           ],
         ),
       ),
     );
  }

  Widget _buildEmployeeSelector() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16.h),
          DropdownButtonFormField2<dynamic>(
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[50], // Very light grey
              prefixIcon: Icon(LineIcons.user, color: _primaryColor),
            ),
            hint: Text(
              'Seleccionar Empleado',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            items: _empleados.map((item) => DropdownMenuItem<dynamic>(
              value: item,
              child: Text(
                item['nombre'],
                style: GoogleFonts.poppins(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: _handleSeleccionarEmpleado,
            value: _empleadoSeleccionado,
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _montoController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: 'Monto por Turno (Bs)',
              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
              prefixIcon: Icon(LineIcons.moneyBill, color: _primaryColor),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _montoTurno = double.tryParse(val) ?? 0;
              });
              _calcularTotalSueldo();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      children: [
        _buildStatCard(
          'Total a Pagar', 
          'Bs. ${_totalSueldo.toStringAsFixed(2)}', 
          LineIcons.wallet, 
          Colors.green,
          isFullWidth: true
        ),
        _buildStatCard(
          'Asistencias', 
          '${_resumen['asistenciasCount'] ?? 0}', 
          LineIcons.checkCircle, 
          Colors.blue
        ),
        _buildStatCard(
          'Faltas', 
          '${(_resumen['faltasInjustificadas'] ?? 0) + (_resumen['faltasJustificadas'] ?? 0)}', 
          LineIcons.timesCircle, 
          Colors.red
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return StaggeredGridTile.count(
      crossAxisCellCount: isFullWidth ? 2 : 1,
      mainAxisCellCount: 1,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (isFullWidth)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Estimado',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  )
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAsistenciasList() {
    if (_loadingAsistencias) {
      return Center(child: SpinKitPulse(color: _primaryColor, size: 40));
    }
    
    if (_asistencias.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(LineIcons.calendarCheck, size: 48, color: Colors.grey[300]),
            SizedBox(height: 10),
            Text(
              'Sin registros recientes',
              style: GoogleFonts.poppins(color: Colors.grey[400]),
            )
          ],
        ),
      );
    }
    
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _asistencias.length,
      itemBuilder: (context, index) {
        final item = _asistencias[index];
        return _buildAsistenciaItem(item, index);
      },
    );
  }

  Widget _buildAsistenciaItem(dynamic item, int index) {
    Color statusColor;
    IconData statusIcon;
    
    switch (item['estado']) {
      case 'Asistido':
        statusColor = Colors.green;
        statusIcon = LineIcons.check;
        break;
      case 'Falta':
        statusColor = (item['justificado'] == 1) ? Colors.orange : Colors.red;
        statusIcon = (item['justificado'] == 1) ? LineIcons.exclamationCircle : LineIcons.times;
        break;
      case 'Tardanza':
        statusColor = Colors.amber;
        statusIcon = LineIcons.clock;
        break;
      case 'Reemplazo':
        statusColor = Colors.blue;
        statusIcon = LineIcons.userFriends;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = LineIcons.question;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          DateFormat('EEEE dd, MMM', 'es').format(DateTime.parse(item['fecha'])),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['estado'],
              style: GoogleFonts.poppins(
                color: statusColor,
                fontWeight: FontWeight.w500,
                fontSize: 12.sp
              ),
            ),
             if (item['reemplazo'] != null)
              Text(
                'Reemplazo: ${item['reemplazo']['nombre']}',
                style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey),
              )
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[400]),
          onSelected: (value) {
            if (value == 'edit') _handleEditarAsistencia(item);
            if (value == 'delete') _handleEliminarAsistencia(item);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(LineIcons.edit, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Editar', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(LineIcons.trash, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX();
  }

  Widget _buildBoletasList() {
    final boletasFiltradas = _boletasPago.where((boleta) =>
      boleta['id_usuario'].toString() == _empleadoSeleccionado!['id'].toString()
    ).toList();

    if (boletasFiltradas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(LineIcons.fileInvoice, size: 48, color: Colors.grey[300]),
            SizedBox(height: 10),
            Text(
              'No hay boletas generadas para este empleado',
              style: GoogleFonts.poppins(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            )
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: boletasFiltradas.length,
      itemBuilder: (context, index) {
        final boleta = boletasFiltradas[index];
        final total = boleta['total'] ?? boleta['monto_neto'] ?? 0;
        final nombreEmpleado = boleta['empleado_nombre'] ?? 
                                (boleta['usuario'] != null ? boleta['usuario']['nombre'] : 'Empleado');
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _primaryColor.withOpacity(0.8),
                child: Text(
                  nombreEmpleado.toString().isNotEmpty ? nombreEmpleado.toString().substring(0, 1).toUpperCase() : 'E',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                nombreEmpleado,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.monetization_on, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Total: Bs. $total',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Fecha de Pago: ${boleta['fecha_pago'] != null && !boleta['fecha_pago'].toString().startsWith('000') ? 
                          DateFormat.yMMMMd('es').format(DateTime.parse(boleta['fecha_pago'])) : "--"}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (boleta['detalles'] != null && (boleta['detalles'] as List).isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.blue),
                      tooltip: 'Ver detalles',
                      onPressed: () => _verDetallesBoleta(boleta),
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    tooltip: 'Imprimir boleta',
                    onPressed: () => _generarBoletaPDF(boleta),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _verDetallesBoleta(dynamic boleta) {
    List detalles = boleta['detalles'] ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de la Boleta', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: detalles.map((d) => ListTile(
            title: Text(d['nombre'] ?? 'Sin nombre', style: GoogleFonts.poppins()),
            subtitle: Text(d['tipo'] ?? '', style: GoogleFonts.poppins(color: d['tipo'] == 'Incentivo' ? Colors.green : Colors.red)),
            trailing: Text(
              '${d['tipo'] == 'Incentivo' ? '+' : '-'} Bs. ${d['monto']}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cerrar'))
        ],
      ),
    );
  }
}
