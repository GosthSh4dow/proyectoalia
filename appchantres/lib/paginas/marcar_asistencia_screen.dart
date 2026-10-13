import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../providers/user_provider.dart';
import '../servicios/asistencia_service.dart';

class MarcarAsistenciaScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  
  const MarcarAsistenciaScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  State<MarcarAsistenciaScreen> createState() => _MarcarAsistenciaScreenState();
}

class _MarcarAsistenciaScreenState extends State<MarcarAsistenciaScreen> {
  final AsistenciaService _asistenciaService = AsistenciaService();
  bool _isLoading = false;
  Map<String, dynamic>? _asistenciaPendiente;
  bool _cargandoEstado = true;
  int? _selectedBranchId;
  bool _showBranchError = false;
  bool _isConnected = false;
  String _localHwid = '';
  String? _connectionError;
  Timer? _timer;
  final Color _primaryColor = const Color(0xFFC026D3);
  final Color _secondaryColor = const Color(0xFFE879F9);

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _selectedBranchId = userProvider.branchId;
    
    // Si no tiene sucursal asignada, seleccionar la primera de la lista por defecto
    if (_selectedBranchId == null && userProvider.sucursales.isNotEmpty) {
      _selectedBranchId = userProvider.sucursales.first['id'];
    }
    
    _verificarEstado();
    _checkLocalConnection();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _checkLocalConnection());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocalConnection() async {
    final result = await _asistenciaService.pingLocalServer();
    if (mounted) {
      setState(() {
        _isConnected = result['ok'];
        _localHwid = result['hwid'] ?? '';
        _connectionError = result['ok'] ? null : result['error'];
      });
    }
  }

  bool _isHwidCorrect() {
    if (!_isConnected || _selectedBranchId == null) return false;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Buscar la sucursal seleccionada en la lista de sucursales del proveedor
    final sucursal = userProvider.sucursales.firstWhere(
      (s) => s['id'] == _selectedBranchId,
      orElse: () => null,
    );
    
    if (sucursal == null || sucursal['hwid'] == null) return false;
    
    // Comparar HWID local detectado con el HWID registrado en la sucursal
    return sucursal['hwid'].toString().toLowerCase().trim() == _localHwid.toLowerCase().trim();
  }

  Future<void> _verificarEstado() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.userId == null) return;

    setState(() => _cargandoEstado = true);
    try {
      final pendientes = await _asistenciaService.obtenerAsistenciasPendientes(userProvider.userId!);
      if (pendientes.isNotEmpty) {
        setState(() => _asistenciaPendiente = pendientes.first);
      } else {
        setState(() => _asistenciaPendiente = null);
      }
    } catch (e) {
      debugPrint('Error verificando estado: $e');
    } finally {
      setState(() => _cargandoEstado = false);
    }
  }

  Future<void> _handleMarcar(bool esIngreso) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.userId == null) return;

    if (_selectedBranchId == null) {
      setState(() => _showBranchError = true); // Set error state for dropdown
      _showSnackBar('Debe seleccionar una sucursal primero', isError: true);
      return;
    } else {
      setState(() => _showBranchError = false); // Clear error state if a branch is selected
    }

    setState(() => _isLoading = true);

    try {
      // 1. Obtener firma del servidor local (valida presencia física)
      final firmaData = await _asistenciaService.solicitarFirmaLocal(userProvider.userId!);
      
      final String horaActual = DateFormat('HH:mm:ss').format(DateTime.now());

      if (esIngreso) {
        // 2. Enviar a la nube
        await _asistenciaService.registrarAsistenciaNube({
          'id_usuario': userProvider.userId,
          'id_sucursal': _selectedBranchId,
          'ingreso': horaActual,
          'timestamp': firmaData['timestamp'],
          'nonce': firmaData['nonce'],
          'hwid': firmaData['hwid'],
          'signature': firmaData['signature'],
        });
        _showSnackBar('Ingreso registrado con éxito', isError: false);
      } else {
        // Marcando salida
        await _asistenciaService.registrarSalidaNube({
          'id_usuario': userProvider.userId,
          'salida': horaActual,
          'id_asistencia': _asistenciaPendiente?['id'],
          'timestamp': firmaData['timestamp'],
          'nonce': firmaData['nonce'],
          'hwid': firmaData['hwid'],
          'signature': firmaData['signature'],
        });
        _showSnackBar('Salida registrada con éxito', isError: false);
      }

      await _verificarEstado();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showConfigIPDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String currentIp = prefs.getString('local_attendance_ip') ?? '192.168.1.100';
    final TextEditingController ipController = TextEditingController(text: currentIp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Configurar IP Local', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingrese la IP del servidor de asistencia (ej: 192.168.1.100). El puerto 5000 se asume por defecto.',
              style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey),
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'IP del Servidor',
                prefixIcon: const Icon(LineIcons.wifi),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Probar la IP que está escrita actualmente en el TextField
              final result = await _asistenciaService.pingLocalServer(baseUrl: ipController.text.trim());
              String hwidMostrar = result['hwid'] != null ? AsistenciaService.maskHwid(result['hwid']) : 'Desconocido';
              _showSnackBar(
                result['ok'] ? 'Conexión exitosa. Equipo: $hwidMostrar' : 'Error: ${result['error']}',
                isError: !result['ok'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Probar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('local_attendance_ip', ipController.text.trim());
              _checkLocalConnection();
              if (mounted) Navigator.pop(context);
              _showSnackBar('Configuración guardada', isError: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4FF),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusCard(),
                  SizedBox(height: 20.h),
                  _buildBranchDropdown(),
                  SizedBox(height: 20.h),
                  if (_cargandoEstado)
                    const SpinKitThreeBounce(color: Color(0xFFC026D3), size: 30)
                  else
                    _buildActionButtons(),
                  const Spacer(),
                  _buildInstructions(),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.h,
      pinned: true,
      backgroundColor: _primaryColor,
      leading: IconButton(
        icon: const Icon(LineIcons.bars, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      actions: [
        IconButton(
          icon: const Icon(LineIcons.cog, color: Colors.white),
          onPressed: _showConfigIPDialog,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Asistencia',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Círculos decorativos para el estilo "premium"
            Positioned(
              top: -30,
              right: -30,
              child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1)),
            ),
            Positioned(
              top: 20,
              left: -20,
              child: CircleAvatar(radius: 40, backgroundColor: Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              bottom: -20,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF4FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    bool hasPending = _asistenciaPendiente != null;
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (hasPending ? Colors.orange : Colors.blue).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasPending ? LineIcons.clock : LineIcons.userCheck,
              size: 50.sp,
              color: hasPending ? Colors.orange : Colors.blue,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          SizedBox(height: 20.h),
          Text(
            hasPending ? 'Entrada Registrada' : 'Listo para Empezar',
            style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          if (hasPending) ...[
            SizedBox(height: 8.h),
            Text(
              'Marcaste ingreso a las ${_asistenciaPendiente!['ingreso']}',
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14.sp),
            ),
          ],
          SizedBox(height: 20.h),
          _buildConnectionBadge(),
          SizedBox(height: 20.h),
          _buildInfoRow(LineIcons.calendar, DateFormat('EEEE, d MMMM', 'es').format(DateTime.now())),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge() {
    bool hwidOk = _isHwidCorrect();
    Color color = !_isConnected ? Colors.red : (hwidOk ? Colors.green : Colors.orange);
    String text = !_isConnected 
        ? 'Sin Conexión' 
        : (hwidOk ? 'Conectado a Sucursal' : 'Sucursal Incorrecta');
    IconData icon = !_isConnected 
        ? LineIcons.wifi 
        : (hwidOk ? LineIcons.checkCircle : LineIcons.exclamationTriangle);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ).animate(onPlay: (controller) => controller.repeat())
           .fadeIn(duration: 500.ms)
           .then()
           .fadeOut(duration: 500.ms),
          SizedBox(width: 8.w),
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            !_isConnected 
                ? text 
                : (hwidOk ? '$text (${AsistenciaService.maskHwid(_localHwid)})' : text),
            style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    bool hasPending = _asistenciaPendiente != null;
    bool hwidCorrect = _isHwidCorrect();

    if (!_isConnected) {
      return _buildErrorState(
        'Sin conexión al servidor local',
        'Verifica que estés conectado al WiFi de la sucursal y que la IP sea correcta.',
        LineIcons.wifi,
      );
    }

    if (!hwidCorrect) {
      return _buildErrorState(
        'No estás en la sucursal correcta',
        'El identificador del equipo local no coincide con la sucursal seleccionada.',
        LineIcons.mapMarker,
      );
    }

    return Column(
      children: [
        _buildCircleButton(
          onTap: _isLoading ? null : () => _handleMarcar(!hasPending),
          label: hasPending ? 'MARCAR SALIDA' : 'MARCAR ENTRADA',
          color: hasPending ? Colors.red : Colors.green,
          icon: hasPending ? LineIcons.alternateSignOut : LineIcons.alternateSignIn,
        ),
      ],
    );
  }

  Widget _buildErrorState(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.red, size: 40.sp),
          SizedBox(height: 10.h),
          Text(
            title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red[800]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5.h),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15.h),
          TextButton.icon(
            onPressed: _checkLocalConnection,
            icon: const Icon(LineIcons.syncIcon),
            label: const Text('Reintentar'),
          ),
        ],
      ).animate().shake(),
    );
  }

  Widget _buildCircleButton({required VoidCallback? onTap, required String label, required Color color, required IconData icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 180.w,
        height: 180.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withAlpha(200)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const SpinKitRing(color: Colors.white, size: 40, lineWidth: 3)
            else ...[
              Icon(icon, color: Colors.white, size: 50.sp),
              SizedBox(height: 10.h),
              Text(
                label.split(' ')[1],
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ]
          ],
        ),
      ),
    ).animate().scale(delay: 200.ms);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16.sp, color: _primaryColor),
        SizedBox(width: 8.w),
        Text(text, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13.sp)),
      ],
    );
  }

  Widget _buildBranchDropdown() {
    final userProvider = Provider.of<UserProvider>(context);
    final sucursales = userProvider.sucursales;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedBranchId,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(LineIcons.building, color: _primaryColor),
          hintText: 'Seleccionar Sucursal',
          hintStyle: GoogleFonts.poppins(fontSize: 14.sp),
        ),
        items: sucursales.map<DropdownMenuItem<int>>((s) {
          return DropdownMenuItem<int>(
            value: s['id'],
            child: Text(s['nombre'] ?? 'Sin nombre', style: GoogleFonts.poppins(fontSize: 14.sp)),
          );
        }).toList(),
        onChanged: _asistenciaPendiente != null ? null : (val) {
          setState(() => _selectedBranchId = val);
        },
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(LineIcons.infoCircle, color: Colors.blue),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Asegúrese de estar conectado al WiFi de la empresa para poder marcar asistencia.',
              style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }
}
