import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../servicios/api_service.dart';
import '../servicios/inventario_service.dart';
import '../providers/user_provider.dart';
import '../widgets/inventory/inventory_header.dart';
import '../widgets/inventory/scanned_item_card.dart';
import '../widgets/inventory/pending_classification_sheet.dart';

// ─────────────────────────── Colores ───────────────────────────
const Color _primary = Color(0xFFC026D3);
const Color _primaryDark = Color(0xFF701A75);
const Color _primaryLight = Color(0xFFE879F9);
const Color _bg = Color(0xFFFDF4FF);
const Color _success = Color(0xFF22C55E);
const Color _error = Color(0xFFEF4444);
const Color _warning = Color(0xFFF59E0B);

// ══════════════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL — Órdenes de Proveedor
// ══════════════════════════════════════════════════════════════════
class EntradaMasivaScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const EntradaMasivaScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  State<EntradaMasivaScreen> createState() => _EntradaMasivaScreenState();
}

class _EntradaMasivaScreenState extends State<EntradaMasivaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _ordenes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarOrdenes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarOrdenes() async {
    setState(() => _isLoading = true);
    try {
      final resp = await ApiService().dio.get(getApiUrl('pedidos'));
      final all = resp.data as List;
      setState(() {
        _ordenes = all.where((p) => p['tipo'] == 'proveedor').toList();
      });
    } catch (_) {
      _snack('Error al cargar órdenes de proveedor', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, bool ok) {
    showTopSnackBar(
      Overlay.of(context),
      CustomSnackBar.success(
        message: msg,
        backgroundColor: ok ? _success : _error,
      ),
    );
  }

  List<dynamic> get _pendientes =>
      _ordenes.where((o) => o['estado'] == 'pendiente').toList();
  List<dynamic> get _recibidas =>
      _ordenes.where((o) => o['estado'] == 'recibido').toList();

  // ──────────────────── Estado de count chips ────────────────────
  Widget _buildEstadoChip(String label, Color color, int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12.sp, color: color),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── Stats row ───────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildEstadoChip('Total', _primary, _ordenes.length),
            SizedBox(width: 8.w),
            _buildEstadoChip('Pendientes', _warning, _pendientes.length),
            SizedBox(width: 8.w),
            _buildEstadoChip('Recibidas', _success, _recibidas.length),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── Header de AppBar ──────────────────────
  PreferredSizeWidget _buildAppBar(String title, {List<Widget>? actions}) {
    return AppBar(
      backgroundColor: _primary,
      elevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 18.sp,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          widget.onMenuPressed != null ? LineIcons.bars : LineIcons.arrowLeft,
          color: Colors.white,
        ),
        onPressed: widget.onMenuPressed ?? () => Navigator.maybePop(context),
      ),
      actions: actions,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11.sp),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: const [
          Tab(text: 'ÓRDENES'),
          Tab(text: 'RECIBIR'),
          Tab(text: 'DISTRIBUIR'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(
        'Órdenes de Proveedor',
        actions: [
          IconButton(
            icon: const Icon(LineIcons.plusCircle, color: Colors.white),
            onPressed: () => _abrirFormularioOrden(context),
            tooltip: 'Nueva Orden',
          ),
          IconButton(
            icon: const Icon(LineIcons.syncIcon, color: Colors.white),
            onPressed: _cargarOrdenes,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: SpinKitFadingCircle(color: _primary, size: 50.sp))
          : Column(
              children: [
                _buildStatsRow(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ListaOrdenesTab(
                        ordenes: _ordenes,
                        onRefresh: _cargarOrdenes,
                        onRecibirPedido: _recibirPedido,
                        onSnack: _snack,
                      ),
                      _ListaOrdenesTab(
                        ordenes: _pendientes,
                        onRefresh: _cargarOrdenes,
                        onRecibirPedido: _recibirPedido,
                        onSnack: _snack,
                        soloRecibir: true,
                      ),
                      _DistribucionTab(
                        ordenesRecibidas: _recibidas,
                        onSnack: _snack,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: Text(
          'Nueva Orden',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: () => _abrirFormularioOrden(context),
      ),
    );
  }

  Future<void> _recibirPedido(dynamic pedido) async {
    try {
      final svc = InventarioService();
      await svc.recibirPedido(pedido['id']);
      _snack('Pedido ${pedido['codigo']} recibido. Productos en cola.', true);
      _cargarOrdenes();
    } catch (e) {
      _snack('Error al recepcionar: $e', false);
    }
  }

  void _abrirFormularioOrden(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NuevaOrdenSheet(
        onCreated: () {
          _cargarOrdenes();
          _snack('Orden creada exitosamente', true);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 1 & 2 — Lista de Órdenes
// ══════════════════════════════════════════════════════════════════
class _ListaOrdenesTab extends StatelessWidget {
  final List<dynamic> ordenes;
  final Future<void> Function() onRefresh;
  final Future<void> Function(dynamic) onRecibirPedido;
  final void Function(String, bool) onSnack;
  final bool soloRecibir;

  const _ListaOrdenesTab({
    required this.ordenes,
    required this.onRefresh,
    required this.onRecibirPedido,
    required this.onSnack,
    this.soloRecibir = false,
  });

  Color _colorForEstado(String estado) {
    switch (estado) {
      case 'pendiente': return _warning;
      case 'recibido': return _success;
      case 'rechazado': return _error;
      default: return Colors.grey;
    }
  }

  IconData _iconForEstado(String estado) {
    switch (estado) {
      case 'pendiente': return LineIcons.clock;
      case 'recibido': return LineIcons.checkCircle;
      case 'rechazado': return LineIcons.timesCircle;
      default: return LineIcons.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ordenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.shoppingBag, size: 64.sp, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(
              soloRecibir
                  ? 'No hay órdenes pendientes de recibir'
                  : 'No hay órdenes de proveedor',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: ordenes.length,
        itemBuilder: (ctx, i) {
          final o = ordenes[i];
          final estado = o['estado'] ?? 'pendiente';
          final color = _colorForEstado(estado);
          final fecha = o['createdAt'] != null
              ? DateFormat('dd MMM yyyy', 'es').format(DateTime.parse(o['createdAt']))
              : '---';

          return Container(
            margin: EdgeInsets.only(bottom: 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _mostrarDetalle(ctx, o),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_iconForEstado(estado), color: color, size: 14.sp),
                                SizedBox(width: 4.w),
                                Text(
                                  estado.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            fecha,
                            style: GoogleFonts.poppins(
                                fontSize: 11.sp, color: Colors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        o['codigo'] ?? '---',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(LineIcons.user, size: 14.sp, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            o['nombre_cliente'] ?? '---',
                            style: GoogleFonts.poppins(
                                fontSize: 13.sp, color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          Text(
                            'Bs. ${(o['monto_total'] ?? 0.0).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      if (soloRecibir && estado == 'pendiente') ...[
                        SizedBox(height: 14.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _success,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                            icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
                            label: Text(
                              'RECEPCIONAR ORDEN',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.sp),
                            ),
                            onPressed: () => onRecibirPedido(o),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarDetalle(BuildContext ctx, dynamic o) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleOrdenSheet(orden: o, onRecepcionar: onRecibirPedido),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SHEET — Detalle de Orden
// ══════════════════════════════════════════════════════════════════
class _DetalleOrdenSheet extends StatelessWidget {
  final dynamic orden;
  final Future<void> Function(dynamic) onRecepcionar;
  const _DetalleOrdenSheet({required this.orden, required this.onRecepcionar});

  @override
  Widget build(BuildContext context) {
    final estado = orden['estado'] ?? 'pendiente';
    final detalles = (orden['detalles'] as List?) ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDEN DE COMPRA',
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      orden['codigo'] ?? '---',
                      style: GoogleFonts.poppins(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                _EstadoBadge(estado: estado),
              ],
            ),
            SizedBox(height: 20.h),
            Divider(color: Colors.grey.shade200),
            SizedBox(height: 10.h),
            Text(
              'Productos (${detalles.length})',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.sp),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: detalles.length,
                itemBuilder: (_, i) {
                  final d = detalles[i];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                    leading: CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.1),
                      child: Text('x${d['cantidad']}',
                          style: GoogleFonts.poppins(color: _primary, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(d['nombre_producto'] ?? d['producto']?['nombre'] ?? 'Producto',
                        style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    trailing: Text('Bs. ${(d['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 13.sp, color: _primary, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  Text(
                    'Bs. ${(orden['monto_total'] ?? 0.0).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18.sp, color: _primary),
                  ),
                ],
              ),
            ),
            if (estado == 'pendiente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _success,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
                  label: Text('MARCAR COMO RECIBIDO',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14.sp)),
                  onPressed: () {
                    Navigator.pop(context);
                    onRecepcionar(orden);
                  },
                ),
              ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

// Badge de estado reutilizable
class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  Color get _color {
    switch (estado) {
      case 'pendiente': return _warning;
      case 'recibido': return _success;
      case 'rechazado': return _error;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        estado.toUpperCase(),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 11.sp,
          color: _color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SHEET — Nueva Orden a Proveedor
// ══════════════════════════════════════════════════════════════════
class _NuevaOrdenSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _NuevaOrdenSheet({required this.onCreated});

  @override
  State<_NuevaOrdenSheet> createState() => _NuevaOrdenSheetState();
}

class _NuevaOrdenSheetState extends State<_NuevaOrdenSheet> {
  final _formKey = GlobalKey<FormState>();
  final _proveedorCtrl = TextEditingController();
  final _comentariosCtrl = TextEditingController();
  final _productoCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<dynamic> _productos = [];
  List<dynamic> _filteredProductos = [];
  dynamic _selectedProducto;
  bool _isSaving = false;
  bool _isLoadingProductos = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _productoCtrl.addListener(_filtrarProductos);
  }

  Future<void> _cargarProductos() async {
    try {
      final resp = await ApiService().dio.get(getApiUrl('productos'));
      setState(() {
        _productos = resp.data as List;
        _filteredProductos = _productos;
        _isLoadingProductos = false;
      });
    } catch (_) {
      setState(() => _isLoadingProductos = false);
    }
  }

  void _filtrarProductos() {
    final q = _productoCtrl.text.toLowerCase();
    setState(() {
      _filteredProductos = _productos
          .where((p) => (p['nombre'] ?? '').toLowerCase().contains(q))
          .toList();
      if (q.isEmpty) _selectedProducto = null;
    });
  }

  void _agregarItem() {
    if (_selectedProducto == null) return;
    final cant = int.tryParse(_cantidadCtrl.text) ?? 0;
    final precio = double.tryParse(_precioCtrl.text) ?? 0.0;
    if (cant <= 0 || precio <= 0) return;

    setState(() {
      _items.add({
        'producto_id': _selectedProducto['id'],
        'nombre': _selectedProducto['nombre'],
        'cantidad': cant,
        'precio_unitario': precio,
        'subtotal': cant * precio,
      });
      _productoCtrl.clear();
      _cantidadCtrl.clear();
      _precioCtrl.clear();
      _selectedProducto = null;
    });
  }

  double get _total =>
      _items.fold(0.0, (sum, i) => sum + (i['subtotal'] as double));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ApiService().dio.post(getApiUrl('pedidos'), data: {
        'nombre_cliente': _proveedorCtrl.text.trim(),
        'telefono': '00000000',
        'tipo_entrega': 'recojo',
        'tipo': 'proveedor',
        'comentarios': _comentariosCtrl.text.trim(),
        'items': _items.map((i) => {
          'producto_id': i['producto_id'],
          'cantidad': i['cantidad'],
        }).toList(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _comentariosCtrl.dispose();
    _productoCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Header ──
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryDark, _primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
                child: Row(
                  children: [
                    Icon(LineIcons.shoppingBag, color: Colors.white, size: 28.sp),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NUEVA ORDEN DE COMPRA',
                            style: GoogleFonts.poppins(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Órdenes de Proveedor',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LineIcons.times, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Formulario scrolleable ──
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.all(24.w),
                  children: [
                    // Proveedor
                    _buildSectionTitle('DATOS DEL PROVEEDOR'),
                    SizedBox(height: 10.h),
                    _buildField(
                      controller: _proveedorCtrl,
                      label: 'Nombre del Proveedor',
                      icon: LineIcons.truck,
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    SizedBox(height: 10.h),
                    _buildField(
                      controller: _comentariosCtrl,
                      label: 'Notas / Comentarios',
                      icon: LineIcons.stickyNote,
                      maxLines: 2,
                    ),

                    SizedBox(height: 24.h),
                    _buildSectionTitle('AGREGAR PRODUCTOS'),
                    SizedBox(height: 10.h),

                    // Búsqueda producto
                    _buildField(
                      controller: _productoCtrl,
                      label: 'Buscar producto...',
                      icon: LineIcons.search,
                    ),

                    if (_productoCtrl.text.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Container(
                        constraints: BoxConstraints(maxHeight: 160.h),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _primaryLight.withOpacity(0.3)),
                        ),
                        child: _isLoadingProductos
                            ? Center(child: SpinKitThreeBounce(color: _primary, size: 20.sp))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredProductos.take(8).length,
                                itemBuilder: (_, i) {
                                  final p = _filteredProductos[i];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(LineIcons.box, color: _primary, size: 18.sp),
                                    title: Text(p['nombre'], style: GoogleFonts.poppins(fontSize: 13.sp)),
                                    subtitle: Text('Stock: ${p['stock'] ?? 0}', style: GoogleFonts.poppins(fontSize: 11.sp)),
                                    onTap: () {
                                      setState(() {
                                        _selectedProducto = p;
                                        _productoCtrl.text = p['nombre'];
                                        _filteredProductos = [];
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],

                    if (_selectedProducto != null) ...[
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: _cantidadCtrl,
                              label: 'Cantidad',
                              icon: LineIcons.hashtag,
                              inputType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildField(
                              controller: _precioCtrl,
                              label: 'Precio Unitario',
                              icon: LineIcons.dollarSign,
                              inputType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: _primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          icon: const Icon(LineIcons.plusCircle),
                          label: Text('AGREGAR ÍTEM', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          onPressed: _agregarItem,
                        ),
                      ),
                    ],

                    // Lista de ítems
                    if (_items.isNotEmpty) ...[
                      SizedBox(height: 24.h),
                      _buildSectionTitle('RESUMEN DE ORDEN (${_items.length} ítems)'),
                      SizedBox(height: 10.h),
                      ..._items.asMap().entries.map((e) {
                        final i = e.key;
                        final item = e.value;
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _primary.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['nombre'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                    Text('x${item['cantidad']}  ·  Bs. ${item['precio_unitario'].toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text(
                                'Bs. ${(item['subtotal'] as double).toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primary, fontSize: 13.sp),
                              ),
                              SizedBox(width: 8.w),
                              IconButton(
                                icon: Icon(LineIcons.trash, color: _error, size: 18.sp),
                                onPressed: () => setState(() => _items.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Total
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_primaryDark, _primary]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL ORDEN', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12.sp)),
                            Text('Bs. ${_total.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20.sp)),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 80.h), // espacio para el botón
                  ],
                ),
              ),

              // ── Botón guardar fijo ──
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    minimumSize: Size(double.infinity, 54.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                    shadowColor: _primary.withOpacity(0.4),
                  ),
                  onPressed: _isSaving ? null : _guardar,
                  child: _isSaving
                      ? SpinKitThreeBounce(color: Colors.white, size: 22.sp)
                      : Text(
                          'CREAR ORDEN DE COMPRA',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: _primary, margin: EdgeInsets.only(right: 10.w)),
        Text(text, style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? inputType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey),
        prefixIcon: Icon(icon, color: _primary, size: 20.sp),
        filled: true,
        fillColor: _bg,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primaryLight.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primaryLight.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 3 — Distribución / Escaneo Masivo
// ══════════════════════════════════════════════════════════════════
class _DistribucionTab extends StatefulWidget {
  final List<dynamic> ordenesRecibidas;
  final void Function(String, bool) onSnack;

  const _DistribucionTab({
    required this.ordenesRecibidas,
    required this.onSnack,
  });

  @override
  State<_DistribucionTab> createState() => _DistribucionTabState();
}

class _DistribucionTabState extends State<_DistribucionTab> {
  final InventarioService _svc = InventarioService();

  List<dynamic> _sucursales = [];
  int? _selectedSucursalId;
  int? _selectedOrdenId;
  List<dynamic> _productosPendientes = [];
  List<Map<String, dynamic>> _escaneados = [];

  bool _isLoading = false;
  bool _scannerActivo = false;
  final MobileScannerController _scanner = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    try {
      final r = await ApiService().dio.get(getApiUrl('sucursales'));
      setState(() => _sucursales = r.data as List);
    } catch (_) {}
  }

  Future<void> _cargarProductosPendientes() async {
    setState(() => _isLoading = true);
    try {
      final r = await ApiService().dio.get(getApiUrl('productos'));
      final all = r.data as List;
      setState(() => _productosPendientes = all.where((p) => p['estado'] == 'por_clasificar').toList());
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    if (_escaneados.any((e) => e['codigo_barras'] == code)) return;

    HapticFeedback.mediumImpact();
    _vincular(code);
  }

  void _vincular(String code) {
    if (_productosPendientes.isEmpty) {
      widget.onSnack('No hay productos pendientes de clasificar', false);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PendingClassificationSheet(
        barcode: code,
        productosPendientes: _productosPendientes,
        onSelected: (p) {
          final user = Provider.of<UserProvider>(context, listen: false);
          setState(() {
            _escaneados.insert(0, {
              'id_temporal': p['id'],
              'id_sucursal': _selectedSucursalId,
              'cantidad': p['stock'],
              'codigo_barras': code,
              'nombre': p['nombre'],
              'id_usuario': user.user['id'] ?? 0,
            });
            _productosPendientes.removeWhere((x) => x['id'] == p['id']);
          });
          Navigator.pop(context);
          widget.onSnack('Clasificado: ${p['nombre']}', true);
        },
      ),
    );
  }

  Future<void> _commit() async {
    if (_escaneados.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _svc.commitDistribucionMasiva(_escaneados);
      setState(() => _escaneados.clear());
      widget.onSnack('¡Inventario actualizado exitosamente!', true);
    } catch (e) {
      widget.onSnack('Error: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ordenesRecibidas.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(30.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LineIcons.warehouse, size: 70.sp, color: Colors.grey.shade300),
              SizedBox(height: 20.h),
              Text(
                'Sin órdenes recibidas',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.black87),
              ),
              SizedBox(height: 8.h),
              Text(
                'Primero recepciona una orden en la pestaña "RECIBIR" para habilitar la distribución.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return _isLoading
        ? Center(child: SpinKitFadingCircle(color: _primary, size: 50.sp))
        : Column(
            children: [
              // Selección de parámetros
              InventoryHeader(
                sucursales: _sucursales,
                selectedSucursalId: _selectedSucursalId,
                pedidosRecibidos: widget.ordenesRecibidas,
                selectedPedidoId: _selectedOrdenId,
                onSucursalChanged: (v) => setState(() => _selectedSucursalId = v),
                onPedidoChanged: (v) {
                  setState(() {
                    _selectedOrdenId = v;
                    _escaneados.clear();
                  });
                  if (v != null) _cargarProductosPendientes();
                },
              ),

              if (_selectedOrdenId != null && _selectedSucursalId != null) ...[
                // Toggle escáner
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _scannerActivo = !_scannerActivo;
                      if (!_scannerActivo) _scanner.stop();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: _scannerActivo ? _error.withOpacity(0.08) : _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _scannerActivo ? _error : _primary,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_scannerActivo ? LineIcons.stop : LineIcons.camera,
                              color: _scannerActivo ? _error : _primary),
                          SizedBox(width: 10.w),
                          Text(
                            _scannerActivo ? 'DETENER ESCÁNER' : 'ACTIVAR CÁMARA',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: _scannerActivo ? _error : _primary,
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
                      height: 190.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _primary, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: MobileScanner(controller: _scanner, onDetect: _onDetect),
                      ),
                    ),
                  ),

                // Lista de escaneados
                Expanded(
                  child: _escaneados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LineIcons.barcode, size: 48.sp, color: Colors.grey.shade300),
                              SizedBox(height: 10.h),
                              Text('Esperando escaneos...', style: GoogleFonts.poppins(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          itemCount: _escaneados.length,
                          itemBuilder: (_, i) => ScannedItemCard(
                            item: _escaneados[i],
                            onDelete: () => setState(() {
                              _productosPendientes.add({
                                'id': _escaneados[i]['id_temporal'],
                                'nombre': _escaneados[i]['nombre'],
                                'stock': _escaneados[i]['cantidad'],
                              });
                              _escaneados.removeAt(i);
                            }),
                          ),
                        ),
                ),

                // Botón commit
                if (_escaneados.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        minimumSize: Size(double.infinity, 54.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 6,
                        shadowColor: _primary.withOpacity(0.4),
                      ),
                      icon: const Icon(LineIcons.upload, color: Colors.white),
                      label: Text(
                        'CONFIRMAR ENTRADAS (${_escaneados.length})',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15.sp, color: Colors.white),
                      ),
                      onPressed: _commit,
                    ),
                  ),
              ] else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LineIcons.store, size: 60.sp, color: Colors.grey.shade200),
                        SizedBox(height: 14.h),
                        Text('Selecciona una sucursal y una\noriden recibida para continuar',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13.sp)),
                      ],
                    ),
                  ),
                ),
            ],
          );
  }
}
