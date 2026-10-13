import 'dart:async';
import 'dart:convert';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import 'package:shimmer/shimmer.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../providers/user_provider.dart';
import '../servicios/api_service.dart';
import '../servicios/inventario_service.dart';
import '../servicios/whatsapp_service.dart';


class PedidosScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  
  const PedidosScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _PedidosScreenState createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allPedidos = [];
  List<dynamic> _filteredPedidos = [];
  final InventarioService _inventarioService = InventarioService();
  bool _isLoading = false;

  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic>? _selectedPedido;
  bool _isDetailLoading = false;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Estadísticas
  Map<String, int> _estadisticas = {
    'pendientes': 0,
    'aprobados': 0,
    'rechazados': 0,
    'hechos': 0,
    'total': 0
  };

  // Para la sucursal seleccionada
  dynamic _selectedSucursal;
  List<dynamic> _sucursales = [];

  // Para almacenar usuario actual
  Map<String, dynamic> _userData = {};

  // Para la nueva notificación
  bool _hasNewNotification = false;
  Map<String, dynamic>? _lastPedido;

  // Filtro de origen: todos | whatsapp | tienda
  String _filtroOrigen = 'todos';

  // QR vigente del negocio (se muestra en el detalle y se puede cambiar)
  final WhatsappService _whatsappService = WhatsappService();
  String? _negocioQrUrl;
  bool _cargandoQr = false;

  // Instancia de Dio para las llamadas a la API
  final Dio _dio = ApiService().dio;
  
  // New Theme Colors
  final Color _primaryColor = const Color(0xFFC026D3); // Fuchsia-600
  final Color _secondaryColor = const Color(0xFFE879F9); // Fuchsia-400
  final Color _backgroundColor = const Color(0xFFFDF4FF); // Rose-50

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Cargar datos iniciales
    _loadUserData();
    _fetchSucursales();
    _fetchPedidos();
  }

  Future<void> _loadUserData() async {
    // Reemplazar la carga de SharedPreferences por el provider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _userData = userProvider.user;
      // Si el provider tiene asignada la sucursal (branch), usarla; sino, usar el id_sucursal del usuario
      if (userProvider.branch != null && userProvider.branch!['id'] != null) {
        _selectedSucursal = {'id': userProvider.branch!['id']};
      } else if (userProvider.user.containsKey('id_sucursal')) {
        _selectedSucursal = {'id': userProvider.user['id_sucursal']};
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _aplicarFiltros();
    }
  }

  Future<void> _fetchSucursales() async {
    try {
      final response = await _dio.get(getApiUrl('sucursales'));
      setState(() {
        _sucursales = response.data;
      });
    } catch (e) {
      // Mejorar el manejo de errores para proporcionar más información
      if (e is DioException && e.response?.statusCode == 401) {
        _showSnackBar('Error de autenticación: Sesión expirada o inválida', false);
        // Opcional: Redirigir al login si la autenticación falló
        // Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _showSnackBar('Error al obtener sucursales: $e', false);
      }
    }
  }

  Future<void> _fetchPedidos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.get(getApiUrl('pedidos'));
      setState(() {
        _allPedidos = response.data;

        // Calcular estadísticas
        _estadisticas = {
          'pendientes': _allPedidos.where((p) => p['estado'] == 'pendiente').length,
          'aprobados': _allPedidos.where((p) => p['estado'] == 'aprobado').length,
          'rechazados': _allPedidos.where((p) => p['estado'] == 'rechazado').length,
          'hechos': _allPedidos.where((p) => p['estado'] == 'hecho').length,
          'whatsapp': _allPedidos.where((p) => p['origen'] == 'whatsapp').length,
          'total': _allPedidos.length
        };

        _aplicarFiltros();
      });
    } catch (e) {
      // Mejorar el manejo de errores para proporcionar más información
      if (e is DioException && e.response?.statusCode == 401) {
        _showSnackBar('Error de autenticación: Sesión expirada o inválida', false);
        // Opcional: Redirigir al login si la autenticación falló
        // Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _showSnackBar('Error al cargar pedidos: $e', false);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    String currentTab = _getTabForIndex(_tabController.index);

    List<dynamic> filtered = List.from(_allPedidos);

    // Filtrar por estado de tab
    if (currentTab != 'todos') {
      filtered = filtered.where((pedido) => pedido['estado'] == currentTab).toList();
    }

    // Filtrar por origen (lista de WhatsApp / tienda)
    if (_filtroOrigen == 'whatsapp') {
      filtered = filtered.where((pedido) => pedido['origen'] == 'whatsapp').toList();
    } else if (_filtroOrigen == 'tienda') {
      filtered = filtered.where((pedido) => pedido['origen'] != 'whatsapp').toList();
    }

    // Filtrar por término de búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((pedido) {
        return (pedido['codigo'] != null && pedido['codigo'].toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (pedido['nombre_cliente'] != null && pedido['nombre_cliente'].toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (pedido['telefono'] != null && pedido['telefono'].toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    // Filtrar por rango de fechas
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((pedido) {
        final pedidoDate = DateTime.parse(pedido['createdAt']);
        return pedidoDate.isAfter(_startDate!) &&
            pedidoDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() {
      _filteredPedidos = filtered;
    });
  }

  String _getTabForIndex(int index) {
    switch (index) {
      case 0:
        return 'pendiente';
      case 1:
        return 'aprobado';
      case 2:
        return 'rechazado';
      case 3:
        return 'hecho';
      case 4:
        return 'todos';
      default:
        return 'pendiente';
    }
  }

  Future<void> _refreshData() async {
    await _fetchPedidos();
  }

  void _verDetallePedido(Map<String, dynamic> pedido) {
    setState(() {
      _selectedPedido = pedido;
      _isDetailLoading = true;
    });

    // Si es de WhatsApp, precargar el QR del negocio para mostrarlo en el detalle
    if (pedido['origen'] == 'whatsapp') {
      _cargarNegocioQr();
    }

    // Simular carga de detalles adicionales (podría ser una petición real)
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _isDetailLoading = false;
      });

      _showDetalleBottomSheet(context, pedido);
    });
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _recibirPedido(Map<String, dynamic> pedido) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _inventarioService.recibirPedido(pedido['id']);

      Navigator.pop(context); // Cerrar bottom sheet de detalles
      _showSnackBar('Pedido recepcionado correctamente. Productos pendientes creados.', true);
      _fetchPedidos();
    } catch (e) {
      _showSnackBar('Error al recepcionar pedido: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _aprobarPedido(Map<String, dynamic> pedido) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _dio.post(
        getApiUrl('pedidos/${pedido['id']}/aprobar-enviar-qr'),
        data: {
          'id_sucursal': _selectedSucursal?['id'] ?? _userData['id_sucursal'],
        },
      );

      Navigator.pop(context);
      _showSnackBar(response.data['mensaje'] ?? 'Pedido aprobado correctamente', true);
      _fetchPedidos();
    } catch (e) {
      _showSnackBar('Error al aprobar pedido: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Confirma que el pago llegó: crea la venta, genera el ticket PDF con el
  /// código de recojo y lo envía por WhatsApp. Requiere caja abierta.
  Future<void> _confirmarPago(Map<String, dynamic> pedido) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userId = _userData['id'];
      final sucursalId = pedido['id_sucursal'] ?? _userData['id_sucursal'];
      if (userId == null || sucursalId == null) {
        throw Exception('No se pudo identificar el usuario o la sucursal');
      }

      final response = await _dio.post(
        getApiUrl('pedidos/${pedido['id']}/confirmar-pago'),
        data: {'id_usuario': userId, 'id_sucursal': sucursalId},
      );

      Navigator.pop(context);
      final codigo = response.data['pedido']?['codigo_recojo'] ?? pedido['codigo'] ?? '';
      _showSnackBar('Pago confirmado. Código de recojo: $codigo', true);
      _fetchPedidos();
    } catch (e) {
      _showSnackBar('Error al confirmar pago: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rechazarPedido(Map<String, dynamic> pedido, String motivo) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _dio.put(
        getApiUrl('pedidos/${pedido['id']}/estado'),
        data: {
          'estado': 'rechazado',
          'motivo_rechazo': motivo,
        },
      );

      Navigator.pop(context);
      _showSnackBar('Pedido rechazado correctamente', true);
      _fetchPedidos();
    } catch (e) {
      _showSnackBar('Error al rechazar pedido: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Carga el QR vigente del negocio (una vez por sesión de pantalla).
  Future<void> _cargarNegocioQr() async {
    if (_negocioQrUrl != null || _cargandoQr) return;
    setState(() => _cargandoQr = true);
    try {
      final url = await _whatsappService.negocioQrUrl();
      if (mounted) setState(() => _negocioQrUrl = url);
    } finally {
      if (mounted) setState(() => _cargandoQr = false);
    }
  }

  /// Cambia el QR fijo del negocio eligiendo una imagen de galería/cámara.
  Future<void> _cambiarQr() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() => _cargandoQr = true);
      final url = await _whatsappService.subirQr(picked.path);
      if (mounted) {
        setState(() {
          _negocioQrUrl = url;
          _cargandoQr = false;
        });
        _showSnackBar('QR del negocio actualizado', true);
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoQr = false);
      _showSnackBar('Error al cambiar QR: $e', false);
    }
  }

  Future<void> _realizarVenta(Map<String, dynamic> pedido) async {    try {
      setState(() {
        _isLoading = true;
      });

      final userId = _userData['id'];
      final sucursalId = pedido['id_sucursal'] ?? _userData['id_sucursal'];

      if (userId == null || sucursalId == null) {
        throw Exception('No se pudo identificar el usuario o la sucursal');
      }

      await _dio.post(
        getApiUrl('pedidos/realizar-venta'),
        data: {
          'id_pedido': pedido['id'],
          'id_usuario': userId,
          'id_sucursal': sucursalId,
        },
      );

      Navigator.pop(context);

      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: '¡Venta realizada!',
          message: 'La venta del pedido se ha procesado correctamente.',
          contentType: ContentType.success,
        ),
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);

      _fetchPedidos();
    } catch (e) {
      final snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'Error',
          message: 'Error al realizar la venta: $e',
          contentType: ContentType.failure,
        ),
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDetalleBottomSheet(BuildContext context, Map<String, dynamic> pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(16),
          child: _buildPedidoDetalle(pedido, scrollController),
        ),
      ),
    );
  }

  Widget _buildPedidoDetalle(Map<String, dynamic> pedido, ScrollController scrollController) {
    String estadoPedido = pedido['estado'] ?? '';
    Color estadoColor = _getColorForEstado(estadoPedido);
    
    final cantidadProductos = pedido['detalles']?.length ?? 0;
    final tipoPedido = pedido['tipo_entrega'] == 'delivery' ? 'Delivery' : 'Recojo en tienda';
    
    final montoTotal = pedido['monto_total'] != null 
      ? double.tryParse(pedido['monto_total'].toString()) ?? 0.0 
      : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con estado y acciones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pedido: ${pedido['codigo'] ?? ''}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        
        Divider(),
        
        // Badge de estado
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: estadoColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForEstado(estadoPedido),
                      color: estadoColor,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _capitalizeFirst(estadoPedido),
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              Spacer(),
              
              // Mostrar botones de acción según estado
              if (pedido['estado'] == 'pendiente')
                Row(
                  children: [
                    if (pedido['tipo'] == 'proveedor')
                      ElevatedButton.icon(
                        onPressed: () => _recibirPedido(pedido),
                        icon: Icon(Icons.download_for_offline),
                        label: Text('Recepcionar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _confirmarAprobacion(pedido),
                        icon: Icon(Icons.check_circle),
                        label: Text('Aprobar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _confirmarRechazo(pedido),
                      icon: Icon(Icons.cancel),
                      label: Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
                
              if ((pedido['estado'] == 'aprobado' || pedido['estado'] == 'pago_pendiente') &&
                  !(pedido['venta_realizada'] ?? false))
                (pedido['origen'] == 'whatsapp' || pedido['estado'] == 'pago_pendiente')
                    ? ElevatedButton.icon(
                        onPressed: () => _confirmarPago(pedido),
                        icon: Icon(Icons.verified),
                        label: Text('Confirmar pago'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _realizarVenta(pedido),
                        icon: Icon(Icons.point_of_sale),
                        label: Text('Realizar Venta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF500A2),
                          foregroundColor: Colors.white,
                        ),
                      ),
            ],
          ),
        ),
        
        // Información del pedido en tarjetas
        Expanded(
          child: ListView(
            controller: scrollController,
            children: [
              // Tarjeta de cliente
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Información del Cliente',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Divider(),
                      _infoRow(Icons.badge, 'Cliente', pedido['nombre_cliente'] ?? 'N/A'),
                      _infoRow(Icons.phone, 'Teléfono', pedido['telefono'] ?? 'N/A'),
                      if (pedido['direccion'] != null)
                        _infoRow(Icons.location_on, 'Dirección', pedido['direccion']),
                      _infoRow(
                        pedido['tipo_entrega'] == 'delivery' ? Icons.delivery_dining : Icons.store, 
                        'Tipo de entrega', 
                        tipoPedido
                      ),
                      if (pedido['comprobante_url'] != null) ...[
                        Divider(),
                        Text('Comprobante de pago', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: getImageUrl(pedido['comprobante_url'].toString()),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Center(child: CircularProgressIndicator()),
                            errorWidget: (c, u, e) => Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ],
                      _infoRow(Icons.access_time, 'Fecha', _formatDate(pedido['createdAt'])),
                      if (pedido['origen'] == 'whatsapp')
                        _infoRow(Icons.chat, 'Origen', 'WhatsApp'),
                      if (pedido['codigo_recojo'] != null)
                        _infoRow(Icons.confirmation_number, 'Código de recojo', pedido['codigo_recojo'].toString()),
                      if (pedido['expira_en'] != null &&
                          (pedido['estado'] == 'aprobado' || pedido['estado'] == 'pago_pendiente'))
                        _infoRow(Icons.timer_off, 'Pagar antes de', _formatDate(pedido['expira_en'])),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // QR del negocio (solo pedidos WhatsApp): se ve y se puede cambiar
              if (pedido['origen'] == 'whatsapp')
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.qr_code, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'QR de pago del negocio',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Divider(),
                        if (_cargandoQr)
                          Center(child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ))
                        else if (_negocioQrUrl != null && _negocioQrUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: getImageUrl(_negocioQrUrl!),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              placeholder: (c, u) => Center(child: CircularProgressIndicator()),
                              errorWidget: (c, u, e) => Icon(Icons.broken_image, size: 48),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aún no hay QR cargado. Súbelo para enviarlo al aprobar.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _cargandoQr ? null : _cambiarQr,
                            icon: Icon(Icons.upload),
                            label: Text('Cambiar QR'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (pedido['origen'] == 'whatsapp') SizedBox(height: 16),

              // Productos
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Productos ($cantidadProductos)',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Divider(),
                      ..._buildProductosItems(pedido),
                      Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Total:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Bs. ${montoTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFFF500A2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Si hay comentarios
              if (pedido['comentarios'] != null && pedido['comentarios'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.comment, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(
                                'Comentarios',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                          Text(
                            pedido['comentarios'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Si fue rechazado, mostrar el motivo
              if (pedido['estado'] == 'rechazado' && pedido['motivo_rechazo'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    elevation: 2,
                    color: Color(0xFFFFF3F3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Motivo de rechazo',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.red.withOpacity(0.2)),
                          Text(
                            pedido['motivo_rechazo'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.blue;
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      case 'hecho':
        return Colors.teal;
      case 'pago_pendiente':
        return Colors.orange;
      case 'pagado':
        return Colors.purple;
      case 'recibido':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getIconForEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.access_time;
      case 'aprobado':
        return Icons.check_circle;
      case 'rechazado':
        return Icons.cancel;
      case 'hecho':
        return Icons.monetization_on;
      case 'pago_pendiente':
        return Icons.hourglass_top;
      case 'pagado':
        return Icons.verified;
      case 'recibido':
        return Icons.inventory;
      default:
        return Icons.help;
    }
  }
  
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  void _confirmarAprobacion(Map<String, dynamic> pedido) {
    // Verificar si hay una sucursal seleccionada o si el usuario tiene una asignada
    if (_userData['id_sucursal'] == null) {
      _showSnackBar('Selecciona una sucursal antes de aprobar el pedido', false);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aprobar Pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de aprobar este pedido?'),
            SizedBox(height: 10),
            Text('Cliente: ${pedido['nombre_cliente']}'),
            Text('Monto: Bs. ${pedido['monto_total']}'),
            SizedBox(height: 10),
            
            // Si existe más de una sucursal, mostrar selección
            if (_sucursales.length > 1)
              DropdownButtonFormField(
                decoration: InputDecoration(labelText: 'Seleccionar Sucursal'),
                value: _selectedSucursal?['id'],
                items: _sucursales.map<DropdownMenuItem>((sucursal) {
                  return DropdownMenuItem(
                    value: sucursal['id'],
                    child: Text(sucursal['nombre']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSucursal = {'id': value};
                  });
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _aprobarPedido(pedido);
            },
            child: Text('Aprobar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  void _confirmarRechazo(Map<String, dynamic> pedido) {
    final TextEditingController motivoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rechazar Pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por favor, indique el motivo del rechazo:'),
            SizedBox(height: 10),
            TextField(
              controller: motivoController,
              decoration: InputDecoration(
                labelText: 'Motivo de rechazo',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (motivoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Por favor, ingrese un motivo de rechazo'))
                );
                return;
              }
              Navigator.of(context).pop();
              _rechazarPedido(pedido, motivoController.text);
            },
            child: Text('Rechazar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Fecha inválida';
    }
  }
  
  List<Widget> _buildProductosItems(Map<String, dynamic> pedido) {
    final detalles = pedido['detalles'] as List<dynamic>? ?? [];
    
    if (detalles.isEmpty) {
      return [Center(child: Text('No hay productos'))];
    }
    
    return detalles.map<Widget>((detalle) {
      final producto = detalle['producto'] ?? {};
      final cantidad = detalle['cantidad'] ?? 0;
      final precioUnitario = double.tryParse(detalle['precio_unitario'].toString()) ?? 0.0;
      final subtotal = double.tryParse(detalle['subtotal'].toString()) ?? 0.0;
      final imagen = producto['imagen'] ?? '';
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imagen.isNotEmpty 
                ? CachedNetworkImage(
                    imageUrl: getImageUrl(imagen),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: SpinKitPulse(color: _primaryColor, size: 20.0),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
            ),
            SizedBox(width: 12),
            
            // Información del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre'] ?? 'Producto desconocido',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Cantidad: $cantidad',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Precio: Bs. ${precioUnitario.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Subtotal
            Text(
              'Bs. ${subtotal.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Color(0xFFF500A2),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }


  


  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          children: List.generate(5, (index) => 
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.all(16.w),
                height: 140.h,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80.w,
                          height: 20.h,
                          color: Colors.white,
                        ),
                        Container(
                          width: 100.w,
                          height: 12.h,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 16.h,
                                color: Colors.white,
                              ),
                              SizedBox(height: 6.h),
                              Container(
                                width: 150.w,
                                height: 12.h,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80.w,
                          height: 20.h,
                          color: Colors.white,
                        ),
                        Container(
                          width: 80.w,
                          height: 20.h,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ),
        ),
      ),
    );
  }
  
  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final String estado = pedido['estado'] ?? '';
    final montoTotal = double.tryParse(pedido['monto_total']?.toString() ?? '0') ?? 0;
    Color estadoColor = _getColorForEstado(estado);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _verDetallePedido(pedido),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: ID and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pedido['codigo'] ?? '#',
                            style: GoogleFonts.poppins(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                        if (pedido['origen'] == 'whatsapp') ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Color(0xFF25D366).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat, size: 12.sp, color: Color(0xFF25D366)),
                                SizedBox(width: 4.w),
                                Text(
                                  'WhatsApp',
                                  style: GoogleFonts.poppins(
                                    color: Color(0xFF25D366),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatDate(pedido['createdAt']),
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16.h),
                
                // Content: Client Info
                Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_secondaryColor, _primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))
                        ]
                      ),
                      child: Center(
                        child: Text(
                          (pedido['nombre_cliente'] ?? 'A')[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pedido['nombre_cliente'] ?? 'Cliente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(
                                pedido['tipo_entrega'] == 'delivery' ? Icons.delivery_dining : Icons.store,
                                size: 12.sp,
                                color: Colors.grey.shade500,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                pedido['tipo_entrega'] == 'delivery' ? 'Delivery' : 'Recojo en tienda',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Bs. ${montoTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                
                SizedBox(height: 16.h),
                Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                SizedBox(height: 12.h),
                
                // Footer: Status and Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: estadoColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getIconForEstado(estado),
                            size: 14.sp,
                            color: estadoColor,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _capitalizeFirst(estado),
                            style: GoogleFonts.poppins(
                              color: estadoColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action Buttons (Condensed)
                    if (estado == 'pendiente')
                      Row(
                         children: [
                           _buildMiniActionBtn(Icons.check, Colors.green, () => _confirmarAprobacion(pedido)),
                           SizedBox(width: 8.w),
                           _buildMiniActionBtn(Icons.close, Colors.red, () => _confirmarRechazo(pedido)),
                         ],
                      )
                    else if (estado == 'aprobado' && !(pedido['venta_realizada'] ?? false))
                      _buildMiniActionBtn(Icons.point_of_sale, _primaryColor, () => _realizarVenta(pedido), label: 'Vender')
                    else
                      Icon(Icons.chevron_right, color: Colors.grey.shade300),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniActionBtn(IconData icon, Color color, VoidCallback onTap, {String? label}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16.sp, color: color),
              if (label != null) ...[
                 SizedBox(width: 4.w),
                 Text(label, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w600, fontSize: 12.sp))
              ]
            ],
          ),
        ),
      ),
    );
  }

  // Mejora en la visualización de la lista vacía
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined, 
              size: 60, 
              color: Colors.grey
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No hay pedidos disponibles',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Los pedidos que recibas aparecerán aquí',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh),
            label: Text('Actualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF500A2),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshData,
            color: _primaryColor,
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: SizedBox(height: 20.h)),
                _buildFilterSection(),
                _buildOrigenChips(),
                _buildTabChips(),
                _buildPedidosList(),
                SliverToBoxAdapter(child: SizedBox(height: 80.h)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _backgroundColor,
      expandedHeight: 180.h,
      floating: false,
      pinned: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed ?? () => Navigator.of(context).pop(),
      ),
      actions: [
         // Notification Badge
         if (_hasNewNotification)
            badges.Badge(
              position: badges.BadgePosition.topEnd(top: 5, end: 5),
              badgeContent: Text('1', style: TextStyle(color: Colors.white, fontSize: 10)),
              child: IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  setState(() => _hasNewNotification = false);
                  if (_lastPedido != null) {
                    _verDetallePedido(_lastPedido!);
                    setState(() => _lastPedido = null);
                  }
                },
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () {},
            ),
      ],
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
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withOpacity(0.1)),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1)),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 60.h, 24.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                       'Pedidos',
                       style: GoogleFonts.poppins(
                         fontSize: 24.sp,
                         fontWeight: FontWeight.bold,
                         color: Colors.white,
                       ),
                     ),
                     Text(
                       'Gestión de órdenes y entregas',
                       style: GoogleFonts.poppins(
                         fontSize: 13.sp,
                         color: Colors.white.withOpacity(0.9),
                       ),
                     ),
                     SizedBox(height: 16.h),
                     _buildEstadisticasSummary(), // New summary widget
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
     return SliverToBoxAdapter(
       child: Padding(
         padding: EdgeInsets.symmetric(horizontal: 16.w),
         child: Row(
           children: [
             Expanded(
               child: Container(
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(50),
                   boxShadow: [
                     BoxShadow(color: _primaryColor.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 8))
                   ]
                 ),
                 child: TextField(
                   decoration: InputDecoration(
                     hintText: 'Buscar pedido...',
                     hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13.sp),
                     prefixIcon: Icon(LineIcons.search, color: _primaryColor),
                     border: InputBorder.none,
                     contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
                     suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                           setState(() => _searchQuery = '');
                           _aplicarFiltros();
                        }
                     ) : null
                   ),
                   onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _aplicarFiltros();
                   },
                 ),
               ),
             ),
             SizedBox(width: 12.w),
             Container(
               decoration: BoxDecoration(
                 color: Colors.white,
                 shape: BoxShape.circle,
                 boxShadow: [
                    BoxShadow(color: _primaryColor.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 8))
                 ]
               ),
               child: IconButton(
                 icon: Icon(Icons.calendar_today, color: _primaryColor),
                 onPressed: () async {
                    final DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
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
                      _aplicarFiltros();
                    }
                 },
               ),
             )
           ],
         ),
       ),
     );
  }

  /// Filtro de origen: lista de WhatsApp / tienda / todos.
  Widget _buildOrigenChips() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.only(top: 12.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOrigenChip('Todos', 'todos', Icons.list),
            SizedBox(width: 8.w),
            _buildOrigenChip(
              'WhatsApp (${_estadisticas['whatsapp'] ?? 0})',
              'whatsapp',
              Icons.chat,
            ),
            SizedBox(width: 8.w),
            _buildOrigenChip('Tienda', 'tienda', Icons.store),
          ],
        ),
      ),
    );
  }

  Widget _buildOrigenChip(String label, String valor, IconData icon) {
    final bool sel = _filtroOrigen == valor;
    final Color color = valor == 'whatsapp' ? Color(0xFF25D366) : _primaryColor;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroOrigen = valor);
        _aplicarFiltros();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: sel ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: sel ? Colors.transparent : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: (sel ? color : Colors.grey).withOpacity(sel ? 0.4 : 0.1),
              blurRadius: sel ? 8 : 4,
              offset: Offset(0, sel ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: sel ? Colors.white : color),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
                color: sel ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChips() {    return SliverToBoxAdapter(
      child: Container(
        height: 60.h,
        margin: EdgeInsets.only(top: 16.h),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          physics: BouncingScrollPhysics(),
          children: [
            _buildTabChip('Pendientes', _estadisticas['pendientes'] ?? 0, 0, Colors.blue),
            _buildTabChip('Aprobados', _estadisticas['aprobados'] ?? 0, 1, Colors.green),
            _buildTabChip('Rechazados', _estadisticas['rechazados'] ?? 0, 2, Colors.red),
            _buildTabChip('Completados', _estadisticas['hechos'] ?? 0, 3, Colors.teal),
            _buildTabChip('Todos', _estadisticas['total'] ?? 0, 4, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int count, int index, Color color) {
    bool isSelected = _tabController.index == index;
    return Padding(
      padding: EdgeInsets.only(right: 12.w),
      child: GestureDetector(
        onTap: () {
          setState(() => _tabController.index = index);
          _aplicarFiltros();
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected ? [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: Offset(0, 4))
            ] : [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))
            ],
            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                 padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(12)
                 ),
                 child: Text(
                   count > 99 ? '99+' : count.toString(),
                   style: GoogleFonts.poppins(
                     fontSize: 10.sp, 
                     fontWeight: FontWeight.bold,
                     color: isSelected ? Colors.white : color
                   ),
                 ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPedidosList() {
    if (_isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildLoadingShimmer(),
      );
    }
    
    if (_filteredPedidos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final pedido = _filteredPedidos[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: _buildPedidoCard(pedido),
          );
        },
        childCount: _filteredPedidos.length,
      ),
    );
  }
  
  Widget _buildEstadisticasSummary() {
      // Simplified stats for header
      return Row(
         children: [
            _buildHeaderStat('Hoy', _estadisticas['pendientes'].toString(), Icons.access_time),
            SizedBox(width: 16.w),
            _buildHeaderStat('Total', _estadisticas['total'].toString(), Icons.assignment),
         ],
      );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
     return Container(
       padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
       decoration: BoxDecoration(
         color: Colors.white.withOpacity(0.2),
         borderRadius: BorderRadius.circular(12)
       ),
       child: Row(
         children: [
            Icon(icon, color: Colors.white, size: 14.sp),
            SizedBox(width: 6.w),
            Text('$label: $value', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500))
         ],
       ),
     );
  }
}
