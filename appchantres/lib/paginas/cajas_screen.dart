import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui'; // For ImageFilter

import '../api.dart';
import '../providers/user_provider.dart';
import '../widgets/cajas/caja_skeleton_card.dart';

// Definición de Colores Premium (Coincide con Productos y Dashboard)
const Color kPrimaryColor = Color(0xFFC026D3);     // Fuchsia-600
const Color kSecondaryColor = Color(0xFFE879F9);   // Fuchsia-400
const Color kDarkPurple = Color(0xFF701A75);       // Fuchsia-900
const Color kBackgroundLight = Color(0xFFFDF4FF);  // Rose-50 (Fondo General)
const Color kSuccessColor = Color(0xFF22C55E);     // Green-500
const Color kErrorColor = Color(0xFFEF4444);       // Red-500
const Color kWarningColor = Color(0xFFF59E0B);     // Amber-500

class CajasScreen extends StatefulWidget {
  final int? initialSelectedSucursal;
  final VoidCallback? onMenuPressed;
  
  const CajasScreen({Key? key, this.initialSelectedSucursal, this.onMenuPressed}) : super(key: key);

  @override
  _CajasScreenState createState() => _CajasScreenState();
}

class _CajasScreenState extends State<CajasScreen> {
  List<dynamic>? _cajas;
  List<dynamic>? _sucursales;
  List<dynamic>? _historialCajas = [];
  bool _loading = false;
  int? _selectedSucursal;
  Map<String, dynamic>? caja;
  double saldoDisponible = 0.0;

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedSucursal = widget.initialSelectedSucursal;
    _fetchSucursales();
    if (_selectedSucursal != null) {
      _fetchCajas();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    final currentBranchId = userProvider.branchId;
    
    // If the branch changed in UserProvider, update local state and refetch
    if (currentBranchId != null && currentBranchId != _selectedSucursal) {
      setState(() {
        _selectedSucursal = currentBranchId;
        _historialCajas = []; // Always close history on branch switch
      });
      _fetchCajas();
    }
  }

  Future<void> _fetchSucursales() async {
    setState(() => _loading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await userProvider.get('$BASE_URL/sucursales');
      if (mounted) {
        setState(() {
          _sucursales = response.data;
        });
      }
    } catch (error) {
      log('Error fetching sucursales: $error');
      if (mounted) {
        setState(() {
          _sucursales = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCajas() async {
    if (_selectedSucursal == null) return;
    setState(() {
      _loading = true;
      _cajas = null; // Trigger skeleton
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await userProvider.get(
        '$BASE_URL/cajas/status',
        queryParameters: {'id_sucursal': _selectedSucursal},
      );
      if (mounted) {
        final boxData = response.data;
        final estado = boxData['estado'];
        
        setState(() {
          // Only show box in main view if it's actually open
          if (estado == 'abierta' && boxData['caja'] != null) {
            final cajaData = boxData['caja'];
            caja = cajaData;
            _cajas = [cajaData];
            saldoDisponible = double.tryParse(cajaData['saldo_final'].toString()) ?? 0.0;
          } else {
            // Box is closed, don't display it as current
            caja = null;
            _cajas = [];
            saldoDisponible = 0.0;
          }
        });
      }
    } catch (error) {
      log('Error fetching cajas: $error');
      if (mounted) {
        setState(() {
          _cajas = [];
          caja = null;
          saldoDisponible = 0.0;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchHistorialCajas() async {
    if (_selectedSucursal == null) return;
    setState(() => _loading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await userProvider.get(
        '$BASE_URL/cajas/historial',
        queryParameters: {'id_sucursal': _selectedSucursal},
      );
      if (mounted) {
        setState(() {
          // Filter out open boxes from history to prevent duplicates with the main view
          _historialCajas = (response.data as List)
              .where((item) => item['estado'] != 'abierta')
              .toList();
        });
      }
    } catch (error) {
      log('Error fetching historial cajas: $error');
      if (mounted) {
        setState(() {
          _historialCajas = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirCaja(double saldoInicial, bool mantenerSaldo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.userId;
    final currentSelectedSucursal = _selectedSucursal;
    final currentUserRol = userProvider.user['rol'] ?? 'usuario';

    if (currentUserId == null || currentSelectedSucursal == null) {
      _showSnackBar('Error: Información de usuario o sucursal faltante.', isError: true);
      return;
    }
    
    setState(() => _loading = true);

    try {
      if (mantenerSaldo && caja != null) {
        saldoInicial = double.tryParse(caja!['saldo_final'].toString()) ?? 0.0;
      }
      
      final Map<String, dynamic> requestData = {
        'id_sucursal': currentSelectedSucursal,
        'saldo_inicial': saldoInicial,
        'monto_inicial': saldoInicial,
        'abierto_por': currentUserId,
        'rol': currentUserRol,
      };
      
      await userProvider.post('$BASE_URL/cajas/open', data: requestData);
      
      await _fetchCajas();
      _showSnackBar('Caja abierta exitosamente', isError: false);
    } catch (e) {
      log("Error al abrir caja: $e");
      String errorMessage = 'Error al abrir la caja.';
      if (e is DioError && e.response?.data != null) {
         final data = e.response?.data;
         if (data is Map && data.containsKey('message'))  errorMessage = data['message'];
         if (data is Map && data.containsKey('error')) errorMessage = data['error'];
      }
      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Future<void> _cerrarCaja(double ingresos, double egresos, String? justificacion) async {
    try {
      setState(() => _loading = true);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.post(
        '$BASE_URL/cajas/close',
        data: {
          'id_caja': caja!['id'],
          'ingresos': ingresos,
          'egresos': egresos,
          'justificacion': justificacion,
          'cerrado_por': userProvider.userId,
        },
      );
      await _fetchCajas();
      _showSnackBar('Caja cerrada exitosamente', isError: false);
    } catch (error) {
      log('Error closing caja: $error');
      _showSnackBar('Error al cerrar la caja', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.poppins())),
          ],
        ),
        backgroundColor: isError ? kErrorColor : kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    final userProvider = Provider.of<UserProvider>(context);
    final sucursalName = userProvider.branch?['nombre'] ?? 'Seleccione Sucursal';

    return Scaffold(
      backgroundColor: kBackgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(sucursalName),
          
          if (_loading && _cajas == null)
             SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const CajaSkeleton(),
                childCount: 3,
              ),
            )
          else if (_cajas == null || _cajas!.isEmpty)
             SliverToBoxAdapter(
               child: _buildEmptyState(),
             )
          else
             SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final currentCaja = _cajas![index];
                    return _buildCajaCard(currentCaja, isCurrent: true);
                  },
                  childCount: _cajas!.length,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: _buildHistorialButton(),
            ),
          ),
          
          if (_historialCajas != null && _historialCajas!.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 80.h),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final historialCaja = _historialCajas![index];
                    return _buildCajaCard(historialCaja, isCurrent: false);
                  },
                  childCount: _historialCajas!.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  void _showSucursalSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.h),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Seleccionar Sucursal",
                      style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: kDarkPurple,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              if (_sucursales == null || _sucursales!.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32.h),
                  child: Column(
                    children: [
                      Icon(LineIcons.store, size: 48, color: Colors.grey[300]),
                      SizedBox(height: 16.h),
                      Text(
                        "No hay sucursales disponibles",
                        style: GoogleFonts.poppins(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.all(16.h),
                    itemCount: _sucursales!.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final sucursal = _sucursales![index];
                      final isSelected = sucursal['id'] == _selectedSucursal;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSucursal = sucursal['id'];
                            // Update provider branch as well just in case
                             final userProvider = Provider.of<UserProvider>(context, listen: false);
                             if (userProvider.branch?['id'] != sucursal['id']) {
                               // Assuming we might want to switch global context or just local
                               // For now just local
                             }
                          });
                          _fetchCajas();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: isSelected ? kPrimaryColor.withOpacity(0.1) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? kPrimaryColor : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? kPrimaryColor : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!),
                                ),
                                child: Icon(
                                  LineIcons.store,
                                  size: 20,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  sucursal['nombre'] ?? 'Sin Nombre',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? kPrimaryColor : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: kPrimaryColor, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
  }



  Future<void> _registrarEgreso(int cajaId, double monto, String justificacion) async {
    // Si ya tenemos la caja cargada, evitamos poner _loading = true para no disparar el skeleton
    // de toda la lista, dando una sensación de actualización instantánea.
    if (caja == null) setState(() => _loading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      
      final response = await userProvider.post(
        '$BASE_URL/cajas/$cajaId/egresos',
        data: {
          'monto': monto,
          'justificacion': justificacion,
          'id_usuario': userId,
        },
      );

      if (mounted) {
        setState(() {
          // Si el backend devuelve la caja actualizada, la usamos para refrescar la UI al instante
          if (response.data != null && response.data['caja'] != null) {
            final updatedCaja = response.data['caja'];
            caja = updatedCaja;
            _cajas = [updatedCaja];
            saldoDisponible = double.tryParse(updatedCaja['saldo_final'].toString()) ?? 0.0;
          }
          _loading = false;
        });
        _showSnackBar("Egreso registrado correctamente", isError: false);
      }
    } catch (error) {
       log('Error registrando egreso: $error');
       if (mounted) {
         _showSnackBar("Error al registrar egreso", isError: true);
         setState(() => _loading = false);
       }
    } 
  }

  Widget _buildSliverAppBar(String sucursalName) {
    // Override sucursal name from selected if available
    String displaySucursalName = sucursalName;
    if (_selectedSucursal != null && _sucursales != null) {
      final selected = _sucursales!.firstWhere((s) => s['id'] == _selectedSucursal, orElse: () => null);
      if (selected != null) displaySucursalName = selected['nombre'];
    }

    return SliverAppBar(
      expandedHeight: 170.h,
      floating: false,
      pinned: true,
      backgroundColor: kBackgroundLight,
      elevation: 0,
       shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE879F9), Color(0xFFC026D3)],
            ),
          ),
          child: Stack(
            children: [
               Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
               Positioned(
                 bottom: 20,
                 left: 20,
                 right: 20,
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     GestureDetector(
                       onTap: _showSucursalSelectionModal,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.2),
                           borderRadius: BorderRadius.circular(20),
                           border: Border.all(color: Colors.white.withOpacity(0.3)),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Icon(LineIcons.store, color: Colors.white, size: 16),
                             const SizedBox(width: 8),
                             Flexible(
                               child: Text(
                                 displaySucursalName,
                                 style: GoogleFonts.poppins(
                                   color: Colors.white,
                                   fontSize: 13.sp,
                                   fontWeight: FontWeight.w500,
                                 ),
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),
                             const SizedBox(width: 4),
                             const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                           ],
                         ),
                       ),
                     ),
                     SizedBox(height: 12.h),
                     Text(
                       "Gestión de Cajas",
                       style: GoogleFonts.poppins(
                         color: Colors.white,
                         fontSize: 26.sp,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ],
                 ),
               ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed ?? () => Navigator.pop(context),
      ),
      actions: [
         IconButton(
           icon: const Icon(LineIcons.syncIcon, color: Colors.white),
           onPressed: () {
             _fetchCajas();
             if (_historialCajas != null && _historialCajas!.isNotEmpty) _fetchHistorialCajas();
           },
         ),
      ],
    );
  }

  Widget _buildCajaCard(Map<String, dynamic> cajaData, {bool isCurrent = false}) {
    final bool isOpen = cajaData['estado'] == 'abierta';
    final double saldoFinal = double.tryParse(cajaData['saldo_final'].toString()) ?? 0.0;
    final double saldoInicial = double.tryParse(cajaData['saldo_inicial'].toString()) ?? 0.0;
    final double ingresos = double.tryParse(cajaData['ingresos'].toString()) ?? 0.0;
    final double egresos = double.tryParse(cajaData['egresos'].toString()) ?? 0.0;
    final String fecha = cajaData['createdAt'] ?? cajaData['fecha'] ?? 'Fecha no disponible';
    final int cajaId = int.tryParse(cajaData['id'].toString()) ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(20.w),
          childrenPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.w),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: isOpen ? kSuccessColor.withOpacity(0.1) : kErrorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOpen ? Icons.lock_open : Icons.lock,
                          size: 14.sp,
                          color: isOpen ? kSuccessColor : kErrorColor,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          isOpen ? "ABIERTA" : "CERRADA",
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: isOpen ? kSuccessColor : kErrorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(fecha),
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Text(
                "Bs. ${saldoFinal.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: kDarkPurple,
                ),
              ),
              Text(
                "Saldo Actual",
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: Colors.grey[500],
                ),

              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                   if (cajaData['usuario_apertura'] != null)
                    _buildUserLabel("Apertura: ${cajaData['usuario_apertura']['nombre']} (${_formatTime(cajaData['createdAt'])})", Icons.login, Colors.blue),
                   if (cajaData['usuario_cierre'] != null)
                    _buildUserLabel("Cierre: ${cajaData['usuario_cierre']['nombre']} (${_formatTime(cajaData['fecha_cierre'])})", Icons.logout, Colors.grey),
                ],
              ),
                ],
              ),

          children: [
            Divider(color: Colors.grey[100]),
            SizedBox(height: 16.h),
            _buildDetailRow("Saldo Inicial", saldoInicial, Icons.account_balance),
            SizedBox(height: 12.h),
            _buildDetailRow("Ingresos", ingresos, Icons.arrow_upward, color: kSuccessColor),
            SizedBox(height: 12.h),
            _buildDetailRow("Egresos", egresos, Icons.arrow_downward, color: kErrorColor),
            
            if (isCurrent && isOpen) ...[
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      "Egreso", 
                      Icons.money_off, 
                      kWarningColor, 
                      () => _showRegistrarEgresoModal(cajaId)
                    ),
                  ),
                  SizedBox(width: 8.w), // Reduced spacing
                  Expanded(
                    child: _buildActionButton(
                      "Detalles", 
                      Icons.analytics, 
                      kSecondaryColor, 
                      () => _showDetallesCajaModal(cajaId)
                    ),
                  ),
                  SizedBox(width: 8.w), // Reduced spacing
                  Expanded(
                    child: _buildActionButton(
                      "Cerrar", 
                      Icons.lock, 
                      kErrorColor, 
                      () => _showCerrarCajaModal(saldoFinal)
                    ),
                  ),
                ],
              ),
            ] else ...[
               SizedBox(height: 24.h),
               SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                      "Ver Detalles", 
                      Icons.analytics, 
                      kSecondaryColor, 
                      () => _showDetallesCajaModal(cajaId)
                    ),
               )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, IconData icon, {Color color = Colors.grey}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1) == Colors.grey.withOpacity(0.1) 
                    ? Colors.grey[100] 
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16.sp, color: color == Colors.grey ? Colors.grey[600] : color),
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        Text(
          "Bs. ${amount.toStringAsFixed(2)}",
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildUserLabel(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(text, style: GoogleFonts.poppins(fontSize: 10.sp, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (caja != null && caja!['estado'] == 'abierta') {
      return Container(); // Si ya hay caja abierta, no mostrar el FAB principal o cambiarlo a "Registrar Movimiento"
    } else {
      return FloatingActionButton.extended(
        onPressed: _showAbrirCajaModal,
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add),
        label: Text("Abrir Caja", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.inbox, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(
              "No hay cajas activas",
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "Abre una nueva caja para comenzar",
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialButton() {
    return TextButton.icon(
      onPressed: () {
        if (_historialCajas == null || _historialCajas!.isEmpty) {
          _fetchHistorialCajas();
        } else {
           setState(() {
             _historialCajas = []; // Toggle hide
           });
        }
      },
      icon: Icon(_historialCajas == null || _historialCajas!.isEmpty 
          ? LineIcons.history 
          : LineIcons.angleUp, 
          color: kSecondaryColor),
      label: Text(
        _historialCajas == null || _historialCajas!.isEmpty ? "Ver Historial" : "Ocultar Historial", 
        style: GoogleFonts.poppins(color: kSecondaryColor, fontWeight: FontWeight.w600)
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        backgroundColor: kPrimaryColor.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAbrirCajaModal() {
    final TextEditingController saldoController = TextEditingController();
    bool mantenerSaldo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: EdgeInsets.fromLTRB(24.w, 24.w, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.w),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'Abrir Caja',
                    style: GoogleFonts.poppins(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: kDarkPurple,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Ingresa el saldo inicial para comenzar las operaciones.',
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13.sp),
                  ),
                  SizedBox(height: 24.h),
                  
                  TextField(
                    controller: saldoController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontSize: 16.sp),
                    decoration: InputDecoration(
                      labelText: 'Saldo Inicial (Bs.)',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.monetization_on, color: kPrimaryColor),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: kPrimaryColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  SwitchListTile(
                    title: Text('Mantener saldo anterior', style: GoogleFonts.poppins(fontSize: 14.sp)),
                    value: mantenerSaldo,
                    activeColor: kPrimaryColor,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setStateModal(() {
                        mantenerSaldo = value;
                        if (mantenerSaldo && caja != null) {
                          saldoController.text = (double.tryParse(caja!['saldo_final'].toString()) ?? 0.0).toString();
                        } else {
                          saldoController.text = '0.0';
                        }
                      });
                    },
                  ),
                  
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirCaja(double.tryParse(saldoController.text) ?? 0.0, mantenerSaldo);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Confirmar Apertura",
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchResumenCaja(int cajaId) async {
    try {
       final userProvider = Provider.of<UserProvider>(context, listen: false);
       final response = await userProvider.get('$BASE_URL/cajas/resumen/$cajaId');
       return response.data;
    } catch (e) {
      log("Error fetching resumen: $e");
      return {};
    }
  }



  void _showDetallesCajaModal(int cajaId) {
    final future = _fetchResumenCaja(cajaId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                     return Center(
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           CircularProgressIndicator(color: kPrimaryColor),
                           SizedBox(height: 16),
                           Text("Cargando detalles...", style: GoogleFonts.poppins(color: Colors.grey))
                         ],
                       ),
                     );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: kErrorColor),
                            SizedBox(height: 12),
                            Text("Error al cargar datos", style: GoogleFonts.poppins(color: kErrorColor, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final desglose = (data['desglose_usuarios'] as List? ?? []);
                  final double totalVentas = double.tryParse(data['total_ventas_periodo'].toString()) ?? 0.0;
                  final double totalEgresos = double.tryParse(data['total_egresos_periodo'].toString()) ?? 0.0;
                  final double totalNeto = totalVentas - totalEgresos;
                  final String? usuarioApertura = data['usuario_apertura'];
                  final String? usuarioCierre = data['usuario_cierre'];

                  // Use the calculated period totals for the global summary cards
                  // fall back to caja columns only if period totals are 0 or null
                  // Las ventas reales (dinero que entra) es Total - Gemas
                  double totalVentasGross = double.tryParse(data['total_ventas_periodo'].toString()) ?? 0.0;
                  double totalGemas = double.tryParse(data['total_gemas_periodo'].toString()) ?? 0.0;
                  
                  // Ingresos para la caja = Dinero Real (Efectivo + QR)
                  double displayVentas = totalVentasGross - totalGemas;
                  double displayEgresos = double.tryParse(data['total_egresos_periodo'].toString()) ?? 0.0;
                  
                  if (totalVentasGross == 0 && displayEgresos == 0 && data['caja'] != null) {
                      displayVentas = double.tryParse(data['caja']['ingresos'].toString()) ?? 0.0;
                      displayEgresos = double.tryParse(data['caja']['egresos'].toString()) ?? 0.0;
                  }
                  
                  return ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text('Resumen de Caja', style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.bold, color: kDarkPurple)),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text("#$cajaId", style: GoogleFonts.poppins(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                          ),
                        ],
                      ),

                      // Opened/Closed by
                      if (usuarioApertura != null || usuarioCierre != null) ...[
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: [
                            if (usuarioApertura != null)
                              _buildUserLabel("Abrió: $usuarioApertura (${_formatTime(data['caja']['createdAt'])})", Icons.login, Colors.blue),
                            if (usuarioCierre != null)
                              _buildUserLabel("Cerró: $usuarioCierre (${_formatTime(data['caja']['fecha_cierre'])})", Icons.logout, Colors.grey),
                          ],
                        ),
                      ],

                      SizedBox(height: 20),

                      // Summary Row - 3 cards
                      Row(
                        children: [
                          Expanded(child: _buildMiniStat("Ingresos", displayVentas, kSuccessColor, Icons.trending_up)),
                          SizedBox(width: 4),
                          Expanded(child: _buildMiniStat("Egresos", displayEgresos, kErrorColor, Icons.trending_down)),
                          SizedBox(width: 4),
                          Expanded(child: _buildMiniStat("Neto", displayVentas - displayEgresos, kPrimaryColor, Icons.account_balance_wallet)),
                        ],
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Payment Breakdown Row
                      Row(
                        children: [
                          Expanded(child: _buildPaymentLabel("Efec: Bs. ${double.tryParse(data['total_efectivo_periodo'].toString())?.toStringAsFixed(2) ?? '0.00'}", Icons.money, Colors.green)),
                          SizedBox(width: 6),
                          Expanded(child: _buildPaymentLabel("QR: Bs. ${double.tryParse(data['total_qr_periodo'].toString())?.toStringAsFixed(2) ?? '0.00'}", Icons.qr_code, Colors.blue)),
                        ],
                      ),
                      
                      if (data['caja'] != null && (double.tryParse(data['caja']['gemas'].toString()) ?? 0.0) > 0) ...[
                        SizedBox(height: 8),
                        _buildPaymentLabel("Gemas (Descuentos): Bs. ${double.tryParse(data['caja']['gemas'].toString())?.toStringAsFixed(2) ?? '0.00'}", LineIcons.gem, Colors.purple),
                      ],

                      SizedBox(height: 24),
                      
                      // Section: User Breakdown
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 20, color: kDarkPurple),
                          SizedBox(width: 4),
                          Text("Desglose por Usuario", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp, color: kDarkPurple)),
                        ],
                      ),
                      SizedBox(height: 12),
                      
                      if (desglose.isNotEmpty)
                        ...desglose.map<Widget>((userStat) {
                          final double ventas = double.tryParse(userStat['total_ventas'].toString()) ?? 0.0;
                          final double egresos = double.tryParse(userStat['total_egresos'].toString()) ?? 0.0;
                          final int cantVentas = int.tryParse(userStat['cantidad_ventas'].toString()) ?? 0;
                          final int cantEgresos = int.tryParse(userStat['cantidad_egresos'].toString()) ?? 0;
                          final double net = ventas - egresos;
                          final String name = userStat['nombre'] ?? 'Usuario';
                          final double totalMovs = ventas + egresos;
                          
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User header
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: kPrimaryColor,
                                      child: Text(
                                        name.substring(0, min(2, name.length)).toUpperCase(),
                                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                                          Text(
                                            "${cantVentas} venta${cantVentas != 1 ? 's' : ''} · ${cantEgresos} egreso${cantEgresos != 1 ? 's' : ''}",
                                            style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (net >= 0 ? kSuccessColor : kErrorColor).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Bs. ${net.toStringAsFixed(2)}",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.sp,
                                          color: net >= 0 ? kSuccessColor : kErrorColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 12),
                                // Breakdown of payment methods
                                Wrap(
                                   spacing: 4,
                                   runSpacing: 4,
                                   children: [
                                     _buildPaymentLabel("Efec: Bs. ${double.tryParse(userStat['total_efectivo'].toString())?.toStringAsFixed(2) ?? '0.00'}", Icons.money, Colors.green),
                                     _buildPaymentLabel("QR: Bs. ${double.tryParse(userStat['total_qr'].toString())?.toStringAsFixed(2) ?? '0.00'}", Icons.qr_code, Colors.blue),
                                      if ((double.tryParse(userStat['total_gemas'].toString()) ?? 0.0) > 0)
                                        _buildPaymentLabel("Gemas: Bs. ${double.tryParse(userStat['total_gemas'].toString())?.toStringAsFixed(2) ?? '0.00'}", LineIcons.gem, Colors.purple),
                                   ],
                                ),

                                SizedBox(height: 12),
                                // Progress bar
                                if (totalMovs > 0) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      height: 6,
                                      child: Row(
                                        children: [
                                          if (ventas > 0)
                                            Expanded(
                                              flex: (ventas / totalMovs * 100).round(),
                                              child: Container(color: kSuccessColor),
                                            ),
                                          if (egresos > 0)
                                            Expanded(
                                              flex: (egresos / totalMovs * 100).round(),
                                              child: Container(color: kErrorColor),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                ],
                                
                                // Amounts row
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_upward, size: 12, color: kSuccessColor),
                                        SizedBox(width: 4),
                                        Text("Ventas: Bs. ${ventas.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 12.sp, color: kSuccessColor, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_downward, size: 12, color: kErrorColor),
                                        SizedBox(width: 4),
                                        Text("Egresos: Bs. ${egresos.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 12.sp, color: kErrorColor, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      else
                        _buildEmptyMovements(),

                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.black87,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text("Cerrar", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15.sp)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 11.sp, color: color, fontWeight: FontWeight.w500)),
          SizedBox(height: 2),
          Text(
            "Bs. ${amount.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.bold, color: kDarkPurple),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLabel(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w600, fontSize: 12.sp)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Bs. ${amount.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.bold, color: kDarkPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMovements() {
     return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: Column(
            children: [
              Icon(LineIcons.inbox, size: 48, color: Colors.grey[300]),
              SizedBox(height: 12.h),
              Text(
                "Sin movimientos registrados", 
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500
                )
              ),
            ],
          ),
        ),
      );
  }
  void _showRegistrarEgresoModal(int cajaId) {
    final TextEditingController montoController = TextEditingController();
    final TextEditingController justificacionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.w, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.w),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Registrar Egreso',
                  style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: kWarningColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Registra una salida de dinero de la caja.',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13.sp),
                ),
                SizedBox(height: 24.h),
                
                TextField(
                  controller: montoController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 16.sp),
                  decoration: InputDecoration(
                    labelText: 'Monto (Bs.)',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.money_off, color: kWarningColor),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kWarningColor)),
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: justificacionController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(fontSize: 16.sp),
                  decoration: InputDecoration(
                    labelText: 'Justificación',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.description, color: kWarningColor),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kWarningColor)),
                  ),
                ),
                
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final double? monto = double.tryParse(montoController.text);
                      final String justificacion = justificacionController.text;
                      
                      if (monto == null || monto <= 0) {
                        _showSnackBar("Ingresa un monto válido", isError: true);
                        return;
                      }
                      if (justificacion.isEmpty) {
                         _showSnackBar("Ingresa una justificación", isError: true);
                         return;
                      }

                      Navigator.pop(context);
                      _registrarEgreso(cajaId, monto, justificacion);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kWarningColor,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Registrar",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCerrarCajaModal(double saldoActual) {
     if (caja == null) return;
     final int cajaId = caja!['id'];
     final TextEditingController justificacionController = TextEditingController();
     final future = _fetchResumenCaja(cajaId);

     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              padding: EdgeInsets.only(top: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }
                  
                  final data = snapshot.data ?? {};
                  final desglose = data['desglose_usuarios'] as List? ?? [];
                  double totalVentasGross = double.tryParse(data['total_ventas_periodo'].toString()) ?? 0.0;
                  double totalGemas = double.tryParse(data['total_gemas_periodo'].toString()) ?? 0.0;
                  double totalVentas = totalVentasGross - totalGemas;
                  
                  // Fallback to caja values if total is 0
                  if (totalVentasGross == 0 && data['caja'] != null) {
                      totalVentas = double.tryParse(data['caja']['ingresos'].toString()) ?? 0.0;
                  }
                  
                  return Column(
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Cerrar Caja',
                        style: GoogleFonts.poppins(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: kErrorColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "Resumen de la sesión",
                         style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13.sp),
                      ),
                      
                      SizedBox(height: 24.h),
                      // Sales Breakdown
                      if (desglose.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Desglose por Usuario", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                        ),
                        SizedBox(height: 12.h),
                        ...desglose.map<Widget>((userStat) {
                           final double ventas = double.tryParse(userStat['total_ventas'].toString()) ?? 0.0;
                           final double egresos = double.tryParse(userStat['total_egresos'].toString()) ?? 0.0;
                           final String name = userStat['nombre'] ?? 'Usuario';
                           
                           return Container(
                             margin: EdgeInsets.only(bottom: 8.h),
                             padding: EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.grey[50],
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Row(
                               children: [
                                 CircleAvatar(
                                   backgroundColor: kPrimaryColor.withOpacity(0.1),
                                   child: Text(name[0].toUpperCase(), style: GoogleFonts.poppins(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                                 ),
                                 SizedBox(width: 12.w),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                       Row(
                                          children: [
                                             Icon(Icons.arrow_upward, size: 12, color: kSuccessColor),
                                             SizedBox(width: 4),
                                             Text("Ventas: Bs. ${ventas.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 12, color: kSuccessColor)),
                                             SizedBox(width: 8),
                                             Icon(Icons.arrow_downward, size: 12, color: kErrorColor),
                                             SizedBox(width: 4),
                                             Text("Egresos: Bs. ${egresos.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 12, color: kErrorColor)),
                                          ],
                                       )
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           );
                        }).toList(),
                        Divider(),
                      ],
                      
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 24.w),
                          children: [
                            // Resumen de Ventas por Usuario
                            Text(
                              "Desglose de Ventas por Usuario",
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: kDarkPurple,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            if (desglose.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text("No se registraron ventas en este periodo.", style: GoogleFonts.poppins(color: Colors.grey)),
                              )
                            else
                              ...desglose.map((user) {
                                final nombre = user['nombre'] ?? 'Usuario';
                                final monto = double.tryParse(user['total_ventas'].toString()) ?? 0.0;
                                final cantidad = user['cantidad_ventas'] ?? 0;
                                
                                return Container(
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                                        child: Text(nombre[0].toUpperCase(), style: GoogleFonts.poppins(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nombre, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                            Text("$cantidad ventas", style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "+ Bs. ${monto.toStringAsFixed(2)}",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.bold,
                                              color: kSuccessColor,
                                            ),
                                          ),
                                          Icon(Icons.arrow_upward, size: 14, color: kSuccessColor),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              
                            Divider(height: 30.h),
                            
                            // Resumen General
                            _buildDetailRow("Total Ventas", totalVentas, Icons.point_of_sale, color: kSuccessColor),
                            SizedBox(height: 10.h),
                            _buildDetailRow("Saldo Final (Sistema)", saldoActual, Icons.account_balance_wallet, color: kDarkPurple),
                            
                            SizedBox(height: 24.h),
                            
                             TextField(
                              controller: justificacionController,
                              maxLines: 2,
                              style: GoogleFonts.poppins(fontSize: 14.sp),
                              decoration: InputDecoration(
                                labelText: 'Observaciones de Cierre',
                                labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                   _cerrarCaja(
                                     double.tryParse(caja!['ingresos'].toString()) ?? 0.0,
                                     double.tryParse(caja!['egresos'].toString()) ?? 0.0,
                                     justificacionController.text,
                                   );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kErrorColor,
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  "Confirmar Cierre de Caja",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                             SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              ),
            );
          }
        );
      }
     );
  }
}
