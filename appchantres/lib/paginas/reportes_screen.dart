import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:line_icons/line_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appchannels/widgets/animated_empty_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:appchannels/servicios/pdf_service.dart';
import 'package:appchannels/servicios/sucursal_service.dart';
import 'package:appchannels/models/sucursal.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../servicios/api_service.dart';
import '../servicios/reportes_service.dart';

class ReportesScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const ReportesScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _ReportesScreenState createState() => _ReportesScreenState();
}

// Clases de datos para los gráficos
class VentaData {
  final String fecha;
  final double monto;
  final double utilidad;

  VentaData(this.fecha, this.monto, this.utilidad);
}

class UtilidadData {
  final String fecha;
  final double utilidad;

  UtilidadData(this.fecha, this.utilidad);
}

class _ReportesScreenState extends State<ReportesScreen> with SingleTickerProviderStateMixin {
  // Theme Colors
  final Color _primaryColor = const Color(0xFFC026D3);
  final Color _secondaryColor = const Color(0xFFE879F9);
  final Color _backgroundColor = const Color(0xFFFDF4FF);

  final _dio = ApiService().dio;
  bool _loading = false;
  
  // Sucursal Filtering
  final SucursalService _sucursalService = SucursalService();
  List<Sucursal> _sucursales = [];
  int? _selectedSucursalId; // null means "Todas"
  String _selectedReport = 'ventas'; // ventas, productos, cajas
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  
  // Modelos de datos específicos para cada tipo de reporte
  Map<String, dynamic> _ventasData = {};
  List<dynamic> _productosData = [];
  List<dynamic> _egresosData = [];
  // Para manejo de tabs
  late TabController _tabController;
  
  // Variables para estadísticas
  double _totalVentas = 0;
  double _promedioDiario = 0.0;
  int _clientesNuevos = 0;
  // Accounting State
  double _costoVentas = 0; // New
  double _utilidadBruta = 0; // New
  double _gastosOperativos = 0; // New
  double _utilidadNetaOperativa = 0; // New
  
  double _utilidadNeta = 0; // Keep for backward compat/other tabs if needed
  int _productosVendidos = 0;
  
  // Para productos
  int _minStock = 10;

  // Qué se vendió (endpoint contable/lineas, paginado)
  final ReportesService _reportesService = ReportesService();
  List<LineaVendida> _lineasVendidas = [];
  Map<String, dynamic> _lineasTotales = {};
  int _lineasPage = 1;
  int _lineasTotal = 0;
  static const int _lineasLimit = 20;
  bool _cargandoLineas = false;
  bool _exportando = false;

  double get _ticketPromedio {
    final n = (_ventasData['ventas_count'] ?? 0) as int;
    if (n <= 0) return 0;
    return _totalVentas / n;
  }

  int get _ventasCount => (_ventasData['ventas_count'] ?? 0) as int;

  // Para detalles de venta y caja
  Map<String, dynamic>? _selectedVenta;
  bool _detalleModalVisible = false;

  DateTime _safeParseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    String dateStr = dateValue.toString();
    if (dateStr.isEmpty || dateStr == 'null') return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      debugPrint("Error parsing date: $dateStr");
      return DateTime.now();
    }
  }

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    String s = value.toString();
    return int.tryParse(s) ?? (double.tryParse(s)?.toInt() ?? 0);
  }
  
  // Datos para los gráficos
  List<VentaData> _ventasChartData = [];
  List<UtilidadData> _utilidadChartData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchSucursales(); // Cargar sucursales al inicio
    _fetchReportData();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedReport = 'ventas';
            break;
          case 1:
            _selectedReport = 'productos';
            break;
        }
      });
    }
    _fetchSucursales();
    _fetchReportData();
  }
  
  Future<void> _fetchSucursales() async {
    try {
      final sucursales = await _sucursalService.obtenerSucursales();
      setState(() {
        _sucursales = sucursales;
      });
    } catch (e) {
      print('Error loading sucursales: $e');
    }
  }


  Future<void> _fetchReportData() async {
    setState(() => _loading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      
      // Endpoint y parámetros específicos según el tipo de reporte
      String endpoint;
      Map<String, dynamic> queryParams = {};
      
      switch(_selectedReport) {
        case 'ventas':
          endpoint = '$BASE_URL/reportes/ventas/detalle';
          queryParams = {
            'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
            'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
            if (_selectedSucursalId != null) 'sucursalId': _selectedSucursalId.toString(),
          };
          break;
        case 'productos':
          endpoint = '$BASE_URL/reportes/inventario/bajo-stock';
          queryParams = {
            'limitStock': _minStock.toString(),
            if (_selectedSucursalId != null) 'sucursalId': _selectedSucursalId.toString(),
          };
          break;
        default:
          endpoint = '$BASE_URL/reportes/ventas/detalle';
          queryParams = {
            'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
            'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
            if (_selectedSucursalId != null) 'sucursalId': _selectedSucursalId.toString(),
          };
      }
      
      // Intentar cargar datos desde caché mientras esperamos la respuesta
      String cacheKey = 'cached_report_${_selectedReport}_${jsonEncode(queryParams)}';
      String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        _procesarDatosReporte(jsonDecode(cachedData), _selectedReport);
      }
          
      // Realizar la llamada al API
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
      );
      
      // Guardar datos en caché
      await prefs.setString(cacheKey, jsonEncode(response.data));

      // Procesar los datos según el tipo de reporte
      _procesarDatosReporte(response.data, _selectedReport);

      // Qué se vendió (solo tab ventas, en paralelo tolerante a fallos)
      if (_selectedReport == 'ventas') {
        unawaited(_fetchLineas(reset: true));
      }
      
    } catch (e) {
      print('Error al cargar reportes: $e');
      _showSnackBar('Error al cargar los reportes: ${e.toString()}', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }
  
  /// Qué se vendió: paginado server-side (no trae todo el detalle).
  Future<void> _fetchLineas({bool reset = false}) async {
    if (_cargandoLineas) return;
    if (reset) {
      setState(() {
        _lineasPage = 1;
        _lineasVendidas = [];
        _lineasTotal = 0;
      });
    } else if (_lineasPage * _lineasLimit >= _lineasTotal && _lineasTotal > 0) {
      return;
    }
    setState(() => _cargandoLineas = true);
    try {
      final page = await _reportesService.fetchLineas(
        inicio: _startDate,
        fin: _endDate,
        sucursalId: _selectedSucursalId,
        page: reset ? 1 : _lineasPage + 1,
        limit: _lineasLimit,
      );
      if (!mounted) return;
      setState(() {
        _lineasPage = page.page;
        _lineasTotal = page.total;
        _lineasTotales = page.totales;
        if (reset) {
          _lineasVendidas = page.items;
        } else {
          _lineasVendidas = [..._lineasVendidas, ...page.items];
        }
        _cargandoLineas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoLineas = false);
      debugPrint('[reportes] lineas error: $e');
    }
  }

  Future<void> _exportarCsv() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final ok = await _reportesService.exportarYCompartir(
        inicio: _startDate,
        fin: _endDate,
        sucursalId: _selectedSucursalId,
      );
      if (!mounted) return;
      _showSnackBar(
          ok ? 'Reporte CSV compartido' : 'No se pudo exportar el CSV',
          isError: !ok,
          isSuccess: ok);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _procesarDatosReporte(dynamic data, String tipoReporte) {    switch(tipoReporte) {
      case 'ventas':
        setState(() {
          // Handle both Map and direct response formats
          Map<String, dynamic> ventasMap = data is Map<String, dynamic> ? data : {'ventas': data};
          _ventasData = ventasMap;
          
          // Usar totales pre-calculados del backend
          _totalVentas = _safeParseDouble(ventasMap['ingreso_total']);
          _costoVentas = _safeParseDouble(ventasMap['costo_ventas_total']);
          _utilidadBruta = _safeParseDouble(ventasMap['utilidad_bruta']);
          _gastosOperativos = _safeParseDouble(ventasMap['total_gastos_operativos']);
          _utilidadNetaOperativa = _safeParseDouble(ventasMap['utilidad_neta_operativa']);
          _promedioDiario = _safeParseDouble(ventasMap['promedio_diario']);
          _utilidadNeta = _utilidadNetaOperativa; // Consistencia con el resumen superior
          _egresosData = ventasMap['egresos'] ?? [];

          // Contar productos vendidos
          List<dynamic> ventas = ventasMap['ventas'] ?? [];
          _productosVendidos = 0;
          for (var venta in ventas) {
            final detalles = venta['detalles'] ?? [];
            for (var detalle in detalles) {
              _productosVendidos += _safeParseInt(detalle['cantidad']);
            }
          }
          
          // Estimar clientes nuevos (solo para demostración)
          _clientesNuevos = ventas.length ~/ 3;
          
          // Preparar datos para los gráficos
          Map<String, VentaData> ventasPorDia = {};
          for (var venta in ventas) {
            final fecha = DateFormat('yyyy-MM-dd').format(_safeParseDate(venta['fecha']));
            
            if (!ventasPorDia.containsKey(fecha)) {
              ventasPorDia[fecha] = VentaData(fecha, 0, 0);
            }
            
            // Sumar monto y utilidad para el gráfico
            final montoActual = ventasPorDia[fecha]!.monto;
            final utilidadActual = ventasPorDia[fecha]!.utilidad;
            
            final montoAdicional = _safeParseDouble(venta['monto_total']);
            double utilidadAdicional = 0.0;
            
            final detalles = venta['detalles'] ?? [];
            for (var detalle in detalles) {
              final costo = _safeParseDouble(detalle['producto']?['costo']);
              final precio = _safeParseDouble(detalle['precio_unitario']);
              final cantidad = _safeParseInt(detalle['cantidad']);
              utilidadAdicional += (precio - costo) * cantidad;
            }
            
            ventasPorDia[fecha] = VentaData(
              fecha,
              montoActual + montoAdicional,
              utilidadActual + utilidadAdicional
            );
          }
          
          _ventasChartData = ventasPorDia.values.toList()
              ..sort((a, b) => a.fecha.compareTo(b.fecha));
          
          _utilidadChartData = _ventasChartData
              .map((data) => UtilidadData(data.fecha, data.utilidad))
              .toList();
        });
        break;
        
      case 'productos':
        setState(() {
          // Handle both List and Map formats
          if (data is List) {
            _productosData = data;
          } else if (data is Map<String, dynamic>) {
            // If it's a map, try to extract the list from common keys
            _productosData = data['productos'] ?? data['data'] ?? [];
          } else {
            _productosData = [];
          }
        });
        break;
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
          _buildSectionChips(),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
          
          if (_loading)
            SliverFillRemaining(
              child: Center(
                child: SpinKitFadingCircle(color: _primaryColor, size: 50.0),
              ),
            )
          else if (_selectedReport == 'ventas')
            ..._buildVentasReport()
          else
            ..._buildProductosReport(),
            
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: _shareReport,
        child: const Icon(LineIcons.share, color: Colors.white),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _backgroundColor,
      expandedHeight: 140.h,
      floating: false,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed ?? () => Navigator.of(context).pop(),
      ),
      actions: [
        if (_sucursales.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            margin: EdgeInsets.only(right: 16.w),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedSucursalId,
                dropdownColor: _primaryColor,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                hint: Text('Sucursal', style: GoogleFonts.poppins(color: Colors.white70)),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Todas', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                  ..._sucursales.map((sucursal) {
                    return DropdownMenuItem<int?>(
                      value: sucursal.id,
                      child: Text(sucursal.nombre, style: GoogleFonts.poppins(color: Colors.white)),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSucursalId = value;
                  });
                  _fetchReportData();
                },
              ),
            ),
          ),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            gradient: LinearGradient(
              colors: [_secondaryColor, _primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 60.h, 24.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Reportes',
                      style: GoogleFonts.poppins(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Análisis y estadísticas',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
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

  Widget _buildSectionChips() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildChip('Ventas', LineIcons.shoppingCart, 'ventas'),
            _buildChip('Productos', LineIcons.box, 'productos'),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, String value) {
    bool isSelected = _selectedReport == value;
    return Padding(
      padding: EdgeInsets.only(right: 12.w),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedReport = value;
            // Update tab controller index for compatibility if needed, though we rely on _selectedReport variable now
            if (value == 'ventas') _tabController.index = 0;
            else _tabController.index = 1;
          });
    
          _fetchSucursales();
          _fetchReportData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: isSelected ? _primaryColor.withOpacity(0.4) : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                  color: isSelected ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVentasReport() {
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _buildDateRangeFilter(),
            SizedBox(height: 24.h),
            _buildVentasStats(),
            _buildAccountingSummary(),
            SizedBox(height: 24.h),
            _buildTicketCards(),
            SizedBox(height: 24.h),
            _buildVendidosSection(),
            SizedBox(height: 24.h),
            _buildUtilityChart(),
            SizedBox(height: 24.h),
            _buildVentasTable(),
          ]),
        ),
      ),
    ];
  }
  
  
  /// Ticket promedio + unidades: 2 mini-cards.
  Widget _buildTicketCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Ticket promedio',
            'Bs. ${_ticketPromedio.toStringAsFixed(2)}',
            LineIcons.tags,
            Colors.teal,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            'Nº ventas',
            '$_ventasCount',
            LineIcons.receipt,
            Colors.indigo,
          ),
        ),
      ],
    );
  }

  /// Qué se vendió: lista agregada por producto + totales + exportar CSV.
  Widget _buildVendidosSection() {
    String fmtBs(dynamic v) {
      final d = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      return 'Bs. ${d.toStringAsFixed(2)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Qué se vendió${_lineasTotal > 0 ? ' ($_lineasTotal)' : ''}',
              style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800]),
            ),
            OutlinedButton.icon(
              onPressed: _exportando ? null : _exportarCsv,
              icon: _exportando
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LineIcons.fileCsv, size: 18),
              label: Text('CSV',
                  style: GoogleFonts.poppins(
                      fontSize: 12.sp, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (_lineasTotales.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFAE8FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Wrap(
              spacing: 16.w,
              runSpacing: 6.h,
              children: [
                _buildTotalChip('Ingreso', fmtBs(_lineasTotales['ingreso'])),
                _buildTotalChip('Utilidad', fmtBs(_lineasTotales['utilidad']),
                    color: const Color(0xFF15803D)),
                _buildTotalChip(
                    'Margen',
                    '${(_lineasTotales['margen_pct'] is num ? (_lineasTotales['margen_pct'] as num).toDouble() : 0).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        if (_lineasTotales.isNotEmpty) SizedBox(height: 12.h),
        if (_lineasVendidas.isEmpty && !_cargandoLineas)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Sin ventas en este periodo',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13.sp, color: Colors.grey[500]),
            ),
          ),
        ..._lineasVendidas.map(_buildLineaCard),
        if (_cargandoLineas)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_cargandoLineas &&
            _lineasTotal > 0 &&
            _lineasVendidas.length < _lineasTotal)
          Center(
            child: TextButton.icon(
              onPressed: () => _fetchLineas(),
              icon: const Icon(Icons.expand_more),
              label: Text(
                  'Ver más (${_lineasTotal - _lineasVendidas.length} restantes)',
                  style: GoogleFonts.poppins(fontSize: 13.sp)),
            ),
          ),
      ],
    );
  }

  Widget _buildTotalChip(String label, String value, {Color? color}) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey[700]),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.grey[900]),
          ),
        ],
      ),
    );
  }

  Widget _buildLineaCard(LineaVendida l) {
    final utilPositiva = l.utilidad >= 0;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EFF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${l.cantidad}',
                style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF221122)),
                ),
                Text(
                  '${l.cantidad} x Bs. ${l.precioPromedio.toStringAsFixed(2)} · ${l.nroTickets} tickets',
                  style: GoogleFonts.poppins(
                      fontSize: 12.sp, color: const Color(0xFF5B4B5E)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs. ${l.ingreso.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF221122)),
              ),
              Text(
                'Util. Bs. ${l.utilidad.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: utilPositiva
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProductosReport() {    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _buildProductosFilter(),
            SizedBox(height: 20.h),
          ]),
        ),
      ),
      _buildProductosTableSliver(),
    ];
  }
  
  Widget _buildDateRangeFilter() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtrar por Fecha',
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Icon(LineIcons.calendarAlt, color: _primaryColor, size: 20.sp),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(height: 16.h),
          
          // Sucursal Dropdown (if available)

            
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: _primaryColor,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      }
                    );
                    
                    if (picked != null) {
                      setState(() {
                         _startDate = picked.start;
                         _endDate = picked.end;
                      });
                      _fetchReportData();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: _primaryColor, size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800], 
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))
                  ]
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _fetchReportData,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductosFilter() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Mínimo',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryColor.withOpacity(0.2)),
                  ),
                  child: TextFormField(
                    initialValue: _minStock.toString(),
                    style: GoogleFonts.poppins(fontSize: 14.sp),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Ej. 10',
                      prefixIcon: Icon(LineIcons.boxes, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _minStock = int.parse(value);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                     BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))
                  ]
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: _fetchReportData,
                ),
              ),
              if (_selectedReport == 'productos' && _productosData.isNotEmpty) ...[
                SizedBox(width: 12.w),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                       BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))
                    ]
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    onPressed: () => PdfService().generateLowStockReport(_productosData),
                    tooltip: 'Descargar PDF',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildVentasStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen de Ventas',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12.h),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 2;
            double aspectRatio = 1.3;
            
            if (constraints.maxWidth > 600) {
              crossAxisCount = 4;
              aspectRatio = 1.5;
            }
            
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: aspectRatio,
              children: [
                _buildStatCard(
                  'Total Ventas',
                  'Bs. ${_totalVentas.toStringAsFixed(2)}',
                  LineIcons.shoppingCart,
                  Colors.green,
                ),
                GestureDetector(
                  onTap: _showUtilityBreakdownModal,
                   child: _buildStatCard(
                    'Utilidad Neta',
                    'Bs. ${_utilidadNeta.toStringAsFixed(2)}',
                    LineIcons.moneyBill,
                    Colors.blue,
                  ),
                ),
                _buildStatCard(
                  'Productos',
                  _productosVendidos.toString(),
                  LineIcons.box,
                  Colors.orange,
                ),
                GestureDetector(
                  onTap: _showAverageBreakdownModal,
                  child: _buildStatCard(
                    'Promedio',
                    'Bs. ${_promedioDiario.toStringAsFixed(2)}',
                    LineIcons.lineChart,
                    Colors.purple,
                  ),
                ),
              ],
            );
          }
        ),
      ],
    );
  }
  
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountingSummary() {
    // Calculate Margins
    double margenBruto = _totalVentas > 0 ? (_utilidadBruta / _totalVentas) * 100 : 0;
    double margenNeto = _totalVentas > 0 ? (_utilidadNetaOperativa / _totalVentas) * 100 : 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LineIcons.calculator, color: Colors.indigo[600], size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen Contable',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Estado de Resultados',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          
          _buildAccountingRow('(+) Ventas Brutas', _totalVentas, Colors.grey[800]!),
          GestureDetector(onTap: _showUtilityBreakdownModal, child: _buildAccountingRow('(-) Costo de Ventas', _costoVentas, Colors.red[400]!)),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          ),
          GestureDetector(onTap: _showUtilityBreakdownModal, child: _buildAccountingRow('(=) Utilidad Bruta', _utilidadBruta, Colors.indigo[600]!, isBold: true)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Margen Bruto: ${margenBruto.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey[400], fontStyle: FontStyle.italic),
            ),
          ),
          SizedBox(height: 12.h),
          GestureDetector(onTap: _showExpensesBreakdownModal, child: _buildAccountingRow('(-) Gastos Operativos', _gastosOperativos, Colors.orange[400]!)),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          ),
          GestureDetector(onTap: _showExpensesBreakdownModal, child: _buildAccountingRow('(=) Utilidad Neta Ops.', _utilidadNetaOperativa, 
            _utilidadNetaOperativa >= 0 ? Colors.green[600]! : Colors.red[600]!, 
            isBold: true, fontSize: 18.sp
          )),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Margen Neto: ${margenNeto.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey[400], fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAccountingRow(String label, double amount, Color color, {bool isBold = false, double? fontSize}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize ?? 14.sp,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Bs. ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: fontSize ?? 15.sp,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityChart() {
    if (_utilidadChartData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            'No hay datos suficientes',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Utilidad Neta por Día',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            height: 250,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            width: double.infinity,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _utilidadChartData.isNotEmpty 
                    ? _utilidadChartData.map((e) => e.utilidad).reduce((a, b) => a > b ? a : b) * 1.2 
                    : 1000,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'Bs. ${value.toInt()}',
                          style: GoogleFonts.poppins(fontSize: 9.sp),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value.toInt() >= _utilidadChartData.length) {
                          return const Text('');
                        }
                        String fecha = _utilidadChartData[value.toInt()].fecha.toString();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('dd/MM').format(_safeParseDate(fecha)),
                            style: GoogleFonts.poppins(fontSize: 9.sp),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  checkToShowHorizontalLine: (value) => value % 500 == 0,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(
                  _utilidadChartData.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: _utilidadChartData[index].utilidad,
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(4),
                        width: 16,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildVentasTable() {
    List<dynamic> ventas = _ventasData['ventas'] ?? [];
    
    if (ventas.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            'No hay ventas en el período seleccionado',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listado de Ventas',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  dataRowMaxHeight: 60,
                  headingRowColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) => Colors.grey.withOpacity(0.1),
                  ),
                  columns: [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Monto Total')),
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Acción')),
                  ],
                  rows: ventas.map<DataRow>((venta) {
                    return DataRow(
                      cells: [
                        DataCell(Text(DateFormat('yyyy-MM-dd').format(
                          _safeParseDate(venta['fecha'])
                        ))),
                        DataCell(Text('Bs. ${_safeParseDouble(venta['monto_total']).toStringAsFixed(2)}')),
                        DataCell(Text(venta['cliente']?['nombre_completo']?.toString() ?? 'Sin dato')),
                        DataCell(Text(venta['usuario']?['nombre']?.toString() ?? 'Sin dato')),
                        DataCell(
                          Row(
                            children: [
                              SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedVenta = venta;
                                      _detalleModalVisible = true;
                                    });
                                    _showDetalleVentaModal(context, venta);
                                  },
                                  child: Text('Detalle'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Color(0xFFF500A2),
                                    side: BorderSide(color: Color(0xFFF500A2)),
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                height: 36,
                                width: 36,
                                child: IconButton(
                                  icon: Icon(LineIcons.print, color: Colors.blue),
                                  onPressed: () {
                                    _shareReport();
                                  },
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  
  Widget _buildProductosTableSliver() {
    if (_productosData.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 400.h,
          child: AnimatedEmptyState(
            title: 'Stock Saludable',
            message: 'No hay productos con stock bajo en este momento.',
            icon: LineIcons.checkCircle,
            color: Colors.green,
          ),
        ),
      );
    }
    
    int criticalItems = _productosData.where((p) => _safeParseInt(p['stock']) <= 5).length;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Header and Warning (only at index 0)
            if (index == 0) {
               return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   if (criticalItems > 0)
                    Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LineIcons.exclamationTriangle, color: Colors.red, size: 24.sp),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shake(duration: 2000.ms, hz: 4)
                          .then(delay: 2000.ms),
                          
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Atención Requerida',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[800],
                                    fontSize: 16.sp,
                                  ),
                                ),
                                Text(
                                  'Hay $criticalItems productos con stock crítico (5 o menos).',
                                  style: GoogleFonts.poppins(
                                    color: Colors.red[800],
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                  Text(
                    'Productos con Stock Bajo (${_productosData.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildProductItem(0),
                 ],
               );
            }
            
            return _buildProductItem(index);
          },
          childCount: _productosData.length,
        ),
      ),
    );
  }

  Widget _buildProductItem(int index) {
    final producto = _productosData[index];
    int stock = _safeParseInt(producto['stock']);
    Color stockColor = Colors.green;
    
    if (stock <= 5) {
      stockColor = Colors.red;
    } else if (stock <= 15) {
      stockColor = Colors.orange;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Builder(
                  builder: (context) {
                    String imagePath = producto['imagen']?.toString() ?? '';
                    if (imagePath.isEmpty) {
                      return Center(
                        child: Icon(LineIcons.box, color: Colors.grey[400]),
                      );
                    }
                    
                    String imageUrl;
                    if (imagePath.startsWith('http')) {
                      imageUrl = imagePath;
                    } else {
                      String baseUrl = BASE_URL.replaceAll('/api', '');
                      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
                      if (!imagePath.startsWith('/')) imagePath = '/$imagePath';
                      imageUrl = '$baseUrl$imagePath';
                    }
                    
                    return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: Icon(LineIcons.image, color: Colors.grey[300]),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(LineIcons.image, color: Colors.grey[300]),
                        ),
                      );
                  }
                ),
              ),
            ),
            SizedBox(width: 16.w),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre'].toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    producto['categoria']?['nombre'] ?? 'Sin categoría',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Código: ${producto['codigo_barras'] ?? 'N/A'}',
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            
            // Stock Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: stockColor.withOpacity(0.5)),
              ),
              child: Text(
                '$stock u.',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: stockColor,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
  
  Future<void> _showDetalleVentaModal(BuildContext context, Map<String, dynamic> venta) {
    List<dynamic> detalles = venta['detalles'] ?? [];
    double utilidadTotal = 0.0;
    
    detalles.forEach((detalle) {
      final costo = _safeParseDouble(detalle['producto']?['costo']);
      final precio = _safeParseDouble(detalle['precio_unitario']);
      final cantidad = _safeParseInt(detalle['cantidad']);
      utilidadTotal += (precio - costo) * cantidad;
    });
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Detalle de Venta #${venta['id'] ?? ''}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(LineIcons.times),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Información General',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow('Fecha', DateFormat('yyyy-MM-dd HH:mm').format(
                            _safeParseDate(venta['fecha'])
                          )),
                          _buildInfoRow('Cliente', venta['cliente']?['nombre_completo']?.toString() ?? 'Sin dato'),
                          _buildInfoRow('Usuario', venta['usuario']?['nombre']?.toString() ?? 'Sin dato'),
                          
                          Divider(),
                          Text(
                            'Productos',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          for (var detalle in detalles)
                            Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detalle['producto']?['nombre']?.toString() ?? 'Producto no disponible',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 8),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      runSpacing: 4,
                                      children: [
                                        Text('Cantidad: ${detalle['cantidad']}'),
                                        SizedBox(width: 16),
                                        Text('Precio: Bs. ${_safeParseDouble(detalle['precio_unitario']).toStringAsFixed(2)}'),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      runSpacing: 4,
                                      children: [
                                        Text('Subtotal: Bs. ${_safeParseDouble(detalle['subtotal']).toStringAsFixed(2)}'),
                                        SizedBox(width: 16),
                                        Text(
                                          'Utilidad: Bs. ${((_safeParseDouble(detalle['precio_unitario']) - _safeParseDouble(detalle['producto']?['costo'])) * _safeParseInt(detalle['cantidad'])).toStringAsFixed(2)}',
                                          style: TextStyle(color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Bs. ${_safeParseDouble(venta['monto_total']).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Utilidad Neta:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Bs. ${utilidadTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(LineIcons.print),
                            label: Text('Imprimir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _shareReport();
                            },
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            child: Text('Cerrar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showUtilityBreakdownModal() {
    List<dynamic> ventas = _ventasData['ventas'] ?? [];
    Map<int, Map<String, dynamic>> productoMargenes = {};

    for (var venta in ventas) {
      final detalles = venta['detalles'] ?? [];
      for (var detalle in detalles) {
        final prod = detalle['producto'];
        if (prod == null) continue;
        final id = _safeParseInt(prod['id']);
        final nombre = prod['nombre'].toString();
        final costo = _safeParseDouble(prod['costo']);
        final precio = _safeParseDouble(detalle['precio_unitario']);
        final cantidad = _safeParseInt(detalle['cantidad']);

        if (!productoMargenes.containsKey(id)) {
          productoMargenes[id] = {
            'nombre': nombre,
            'cantidad': 0,
            'ingreso': 0.0,
            'costo_total': 0.0,
            'utilidad': 0.0,
          };
        }

        productoMargenes[id]!['cantidad'] += cantidad;
        productoMargenes[id]!['ingreso'] += precio * cantidad;
        productoMargenes[id]!['costo_total'] += costo * cantidad;
        productoMargenes[id]!['utilidad'] += (precio - costo) * cantidad;
      }
    }

    List<Map<String, dynamic>> sortedList = productoMargenes.values.toList()
      ..sort((a, b) => (b['utilidad'] as double).compareTo(a['utilidad'] as double));

    _showBreakdownDialog(
      'Desglose de Utilidad y Costos',
      'Análisis detallado de rentabilidad por producto en este período.',
      Column(
        children: [
          _buildDetailHeader(['Producto', 'Cant.', 'Margen']),
          ...sortedList.map((item) => _buildDetailRow([
            item['nombre'].toString(),
            item['cantidad'].toString(),
            'Bs. ${item['utilidad'].toStringAsFixed(2)}',
          ])),
          _buildSummaryTotal('Utilidad Bruta Total', 'Bs. ${_utilidadBruta.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  void _showExpensesBreakdownModal() {
    _showBreakdownDialog(
      'Desglose de Gastos Operativos',
      'Lista detallada de egresos y gastos registrados en este período.',
      Column(
        children: [
          _buildDetailHeader(['Fecha', 'Descripción', 'Monto']),
          ..._egresosData.map((e) => _buildDetailRow([
            DateFormat('dd/MM').format(_safeParseDate(e['fecha'])),
            'Egreso de Caja', // Backend only sends amount and date for now in proxy
            'Bs. ${_safeParseDouble(e['monto']).toStringAsFixed(2)}',
          ])),
          _buildSummaryTotal('Gastos Totales', 'Bs. ${_gastosOperativos.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  void _showAverageBreakdownModal() {
    int days = _endDate.difference(_startDate).inDays + 1;
    _showBreakdownDialog(
      'Cálculo de Promedio Diario',
      'Cómo se calcula el promedio de ventas por día.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSimpleBreakdownRow('Ventas Totales (A)', 'Bs. ${_totalVentas.toStringAsFixed(2)}'),
          _buildSimpleBreakdownRow('Días en Rango (B)', '$days días'),
          Divider(height: 32.h),
          _buildSimpleBreakdownRow('Promedio (A / B)', 'Bs. ${_promedioDiario.toStringAsFixed(2)}', isTotal: true),
        ],
      ),
    );
  }

  void _showBreakdownDialog(String title, String subtitle, Widget content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.bold, color: _primaryColor)),
                        Text(subtitle, style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LineIcons.times, color: Colors.grey)),
                ],
              ),
              SizedBox(height: 24.h),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: content,
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: Text('Cerrar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader(List<String> columns) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        children: columns.map((c) => Expanded(
          child: Text(c, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.grey[700])),
        )).toList(),
      ),
    );
  }

  Widget _buildDetailRow(List<String> values) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[50]!))),
      child: Row(
        children: values.map((v) => Expanded(
          child: Text(v, style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey[800])),
        )).toList(),
      ),
    );
  }

  Widget _buildSummaryTotal(String label, String value) {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp, color: _primaryColor)),
        ],
      ),
    );
  }

  Widget _buildSimpleBreakdownRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? _primaryColor : null)),
        ],
      ),
    );
  }

  void _shareReport() async {
    String reportTitle;
    String reportContent;
    
    switch(_selectedReport) {
      case 'ventas':
        reportTitle = "Reporte de Ventas";
        reportContent = "Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}\n\n";
        reportContent += "Total Ventas: Bs. ${_totalVentas.toStringAsFixed(2)}\n";
        reportContent += "Utilidad Neta: Bs. ${_utilidadNeta.toStringAsFixed(2)}\n";
        reportContent += "Productos Vendidos: $_productosVendidos\n";
        break;
      case 'productos':
        reportTitle = "Reporte de Productos con Bajo Stock";
        reportContent = "Stock mínimo: $_minStock\n\n";
        reportContent += "Total de productos con bajo stock: ${_productosData.length}\n";
        break;
      default:
        reportTitle = "Reporte";
        reportContent = "Reporte generado desde AppChannels";
    }
    
    await Share.share(
      '$reportTitle\n\n$reportContent\n\nGenerado por AppChannels el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      subject: reportTitle,
    );
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final overlayState = Overlay.of(context);
    if (overlayState == null) return;
    
    if (isError) {
      showTopSnackBar(
        overlayState,
        CustomSnackBar.error(message: message),
      );
    } else if (isSuccess) {
      showTopSnackBar(
        overlayState,
        CustomSnackBar.success(message: message),
      );
    } else {
      showTopSnackBar(
        overlayState,
        CustomSnackBar.info(message: message),
      );
    }
  }
}
