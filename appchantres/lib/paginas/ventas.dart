// ventas.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Añadimos esta importación para HapticFeedback
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui'; // Para usar ImageFilter en el blur
import 'dart:math' as math; // <-- Importar dart:math
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servicios/scanner_cooldown.dart';
import '../widgets/sales/continuous_scanner_strip.dart';
import '../api.dart'; // Debe exportar const String BASE_URL = "...";
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../components/PrinterSettings.dart';
import '../components/PrinterService.dart'; // Asegurarse de importar el nuevo servicio
import '../widgets/sales/sales_product_card.dart';
import '../widgets/sales/sales_summary_modal.dart';
import '../widgets/sales/sales_product_grid.dart';
import '../models/producto.dart';
import '../models/cliente.dart'; // Import models
import '../servicios/producto_service.dart'; // Import service
import '../widgets/scan_screen.dart'; // Import ScanScreen
import '../widgets/sales/skeleton_product_card.dart'; // Import Skeleton Widget
import '../servicios/api_service.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

// Definición de Colores Premium (Coincide con Productos y Dashboard)
const Color kPrimaryColor = Color(0xFFC026D3);     // Fuchsia-600
const Color kSecondaryColor = Color(0xFFE879F9);   // Fuchsia-400
const Color kDarkPurple = Color(0xFF701A75);       // Fuchsia-900
const Color kBackgroundLight = Color(0xFFFDF4FF);  // Rose-50 (Fondo General)
const Color kSuccessColor = Color(0xFF22C55E);     // Green-500
const Color kErrorColor = Color(0xFFEF4444);       // Red-500
const Color kWarningColor = Color(0xFFF59E0B);     // Amber-500

// Extensión para firstWhereOrNull
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// Local classes Producto and Cliente removed. Using imported models.

// ScanScreen removed. Imported from widgets.
class VentasScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const VentasScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _VentasScreenState createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  // Controladores y FocusNodes
  TextEditingController barcodeController = TextEditingController();
  TextEditingController filtroNombreController = TextEditingController();
  TextEditingController filtroCategoriaController = TextEditingController();
  TextEditingController ciController = TextEditingController();
  TextEditingController nombreClienteController = TextEditingController();
  TextEditingController montoEntregadoController = TextEditingController();

  FocusNode barcodeFocus = FocusNode();

  // Estados
  List<Producto> productos = [];
  List<Producto> productosFiltrados = [];
  List<Map<String, dynamic>> carrito = [];
  Cliente? cliente;
  final ProductoService _productoService = ProductoService(); // Instancia del servicio

  String codigoBarras = "";
  bool loading = false;
  bool filtering = false;
  bool noReceipt = false;
  bool saving = false;
  bool isResumenOpened = false;
  bool loadingCliente = false;
  dynamic _selectedCategoryFilter;
  List<dynamic>? _sucursales;
  int? _selectedSucursal;
  int? _idCajaActiva;
  String? _estadoCaja;

  double montoEntregado = 0.0;
  double cambio = 0.0;
  double gemasVenta = 0.0;
  String tipoPagoVenta = 'efectivo';
  double montoQRVenta = 0.0;
  int? idUsuarioPersonalVenta;
  String? nombrePersonalVenta;
  double descuentoPersonalVenta = 0.0;

  // Caché de productos
  DateTime? _lastFetched;

  // Lector continuo estilo supermercado (fase 1).
  // mobile_scanner NO tiene implementación en desktop: solo Android/iOS.
  static bool get _scannerSoportado {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  MobileScannerController? _scannerController;
  final ValueNotifier<bool> _scanFlash = ValueNotifier(false);
  final ScannerCooldown _cooldown = ScannerCooldown();
  bool _scannerPausado = false;

  // Catálogo paginado + índice O(1) por código (fase 2, 5960 productos)
  final Map<String, Producto> _indiceBarras = {};
  int _paginaProd = 1;
  static const int _limiteProd = 100;
  bool _hasMoreProd = true;
  bool _cargandoPagina = false;
  bool _busquedaServer = false;
  final ScrollController _ventasScrollCtrl = ScrollController();

  // Carrito O(1): índice id -> posición en `carrito`
  final Map<int, int> _cartIndex = {};
  bool _requestLock = false;

  // Overlay de éxito post-venta (el modal ya se cerró: feedback visible).
  bool _mostrarExito = false;
  double _exitoTotal = 0;
  int _exitoItems = 0;

  void _mostrarExitoVenta(double total, int items) {
    if (!mounted) return;
    setState(() {
      _exitoTotal = total;
      _exitoItems = items;
      _mostrarExito = true;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _mostrarExito = false);
    });
  }

  void _rebuildCartIndex() {
    _cartIndex.clear();
    for (var i = 0; i < carrito.length; i++) {
      final id = carrito[i]['id'];
      if (id is int) _cartIndex[id] = i;
    }
  }

  void _setCarrito(List<Map<String, dynamic>> nuevo) {
    carrito = nuevo;
    _rebuildCartIndex();
  }

  void _reconstruirIndice() {
    _indiceBarras.clear();
    for (final p in productos) {
      if (p.codigoBarras.isNotEmpty) {
        _indiceBarras[p.codigoBarras.toUpperCase()] = p;
      }
      for (final c in (p.codigos ?? <dynamic>[])) {
        try {
          final cb = (c as dynamic).codigo.toString().toUpperCase();
          if (cb.isNotEmpty) _indiceBarras[cb] = p;
        } catch (_) {}
      }
    }
  }

  // DATOS DE VENTA / RECIBO
  Map<String, dynamic>? ventaData;
  List<dynamic> detallesVenta = [];
  bool pdfVisible = false;

  Timer? debounceTimer;

  @override
  void initState() {
    super.initState();
    if (_scannerSoportado) {
      _scannerController = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        detectionTimeoutMs: 1500,
        torchEnabled: false,
      );
    }
    _ventasScrollCtrl.addListener(_onVentasScroll);
    _loadProductosCached().then((_) => fetchProductos());
    filtroNombreController.addListener(_onFiltroChanged);
    filtroCategoriaController.addListener(_onFiltroChanged);
    
    // Inicializar sucursal desde provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        _selectedSucursal = userProvider.branchId;
      });
      _fetchSucursales();
      if (_selectedSucursal != null) {
        _fetchEstadoCaja();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El branchId del provider puede llegar después del initState: cuando
    // aparezca, auto-seleccionar sucursal + caja sin toque manual.
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final b = userProvider.branchId;
    if (b != null && b != _selectedSucursal) {
      _selectedSucursal = b;
      _fetchEstadoCaja();
      if (mounted) setState(() {});
    }
  }

  /// Pausa/reanuda el lector tragando MissingPluginException (desktop) y
  /// carreras start-durante-init (await + catch: el start() sin await
  /// dejaba Unhandled Exception controllerInitializing).
  Future<void> _pausarScanner([String motivo = '']) async {
    final c = _scannerController;
    if (c == null) return;
    try {
      await c.stop();
    } catch (_) {}
    if (motivo.isNotEmpty) debugPrint('[scanner] paused $motivo');
  }

  Future<void> _reanudarScanner() async {
    final c = _scannerController;
    if (c == null || !mounted || isResumenOpened) return;
    try {
      await c.start();
    } catch (_) {}
    debugPrint('[scanner] resumed');
  }

  void _onVentasScroll() {
    if (!_ventasScrollCtrl.hasClients) return;
    if (_ventasScrollCtrl.position.pixels >=
            _ventasScrollCtrl.position.maxScrollExtent - 800 &&
        !_cargandoPagina &&
        _hasMoreProd &&
        !_busquedaServer &&
        !loading) {
      _cargarPaginaSiguiente();
    }
  }

  @override
  void dispose() {
    _ventasScrollCtrl.dispose();
    _scanFlash.dispose();
    final c = _scannerController;
    _scannerController = null;
    if (c != null) {
      try {
        c.stop();
      } catch (_) {}
      try {
        c.dispose();
      } catch (_) {}
    }
    barcodeController.dispose();
    filtroNombreController.dispose();
    filtroCategoriaController.dispose();
    ciController.dispose();
    nombreClienteController.dispose();
    montoEntregadoController.dispose();
    debounceTimer?.cancel();
    barcodeFocus.dispose(); // Asegurarse de disponer el FocusNode
    super.dispose();
  }

  /// Getter para "total"
  double get total => calcularTotal();

  // =========================================================
  // CACHÉ DE PRODUCTOS
  // =========================================================
  Future<void> _loadProductosCached() async {
    final prefs = await SharedPreferences.getInstance();
    String? cached = prefs.getString('cached_products');
    if (cached != null) {
      List decoded = jsonDecode(cached);
      List<Producto> prods =
          decoded.map((json) => Producto.fromJson(json)).toList();
      setState(() {
        productos = prods;
        productosFiltrados = prods;
      });
    }
  }

  Future<void> _cacheProductos(List<Producto> prods) async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(prods.map((p) => p.toJson()).toList());
    await prefs.setString('cached_products', encoded);
  }

  // =========================================================
  // 1. CARGA INICIAL DE PRODUCTOS
  // =========================================================
  Future<void> fetchProductos() async {
    // Paginado server-side: página 1 x 100 (antes traía 5960 de golpe).
    setState(() {
      loading = true;
      _paginaProd = 1;
      _hasMoreProd = true;
      _busquedaServer = false;
      if (_selectedSucursal != null) {
          productos = [];
          productosFiltrados = [];
      }
    });
    try {
      final prods = await _productoService.obtenerProductosPaginados(
        idSucursal: _selectedSucursal,
        page: 1,
        limit: _limiteProd,
      );

      final uniqueProds = _dedupPorId(prods);

      if (!mounted) return;
      setState(() {
        productos = uniqueProds;
        productosFiltrados = uniqueProds;
        _hasMoreProd = prods.length == _limiteProd;
        _lastFetched = DateTime.now();
      });
      _reconstruirIndice();
      // Caché liviana: solo primera página (no 5960 en SharedPreferences).
      if (uniqueProds.length <= 150) await _cacheProductos(uniqueProds);
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        Overlay.of(context)!,
        CustomSnackBar.error(
          message: "Error al cargar los productos: $e",
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  List<Producto> _dedupPorId(List<Producto> prods) {
    final map = <int, Producto>{};
    for (var p in prods) {
      map[p.id] = p;
    }
    return map.values.toList();
  }

  Future<void> _cargarPaginaSiguiente() async {
    if (_cargandoPagina || !_hasMoreProd) return;
    _cargandoPagina = true;
    final next = _paginaProd + 1;
    try {
      final prods = await _productoService.obtenerProductosPaginados(
        idSucursal: _selectedSucursal,
        page: next,
        limit: _limiteProd,
      );
      if (!mounted) return;
      if (prods.isEmpty) {
        setState(() => _hasMoreProd = false);
        return;
      }
      final ids = productos.map((p) => p.id).toSet();
      final nuevos = prods.where((p) => !ids.contains(p.id)).toList();
      setState(() {
        _paginaProd = next;
        productos = [...productos, ...nuevos];
        productosFiltrados = [...productosFiltrados, ...nuevos];
        if (prods.length < _limiteProd) _hasMoreProd = false;
      });
      _reconstruirIndice();
    } catch (_) {
      // Silencioso: el usuario sigue con lo cargado.
    } finally {
      _cargandoPagina = false;
    }
  }

  Future<void> _fetchSucursales() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await userProvider.get('$BASE_URL/sucursales');
      if (mounted) {
        setState(() {
          _sucursales = response.data;
        });
      }
    } catch (error) {
      print('Error fetching sucursales: $error');
    }
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
                            final userProvider = Provider.of<UserProvider>(context, listen: false);
                            userProvider.selectSucursal(sucursal['id'], sucursalData: sucursal);
                          });
                          fetchProductos(); 
                          _fetchEstadoCaja();
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
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LineIcons.store,
                                color: isSelected ? kPrimaryColor : Colors.grey[400],
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  sucursal['nombre'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? kDarkPurple : Colors.grey[700],
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: kPrimaryColor, size: 20.sp),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // 2. FILTROS CON DEBOUNCE
  // =========================================================
  void _onFiltroChanged() {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final nombreQ = filtroNombreController.text.trim();
      // Búsqueda server-side con 2+ letras (no filtrar miles en RAM).
      if (nombreQ.length >= 2) {
        setState(() => filtering = true);
        try {
          final prods = await _productoService.buscarProductosServer(
            idSucursal: _selectedSucursal,
            query: nombreQ,
          );
          if (!mounted) return;
          setState(() {
            productosFiltrados = _dedupPorId(prods);
            _busquedaServer = true;
            filtering = false;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => filtering = false);
        }
        return;
      }
      if (nombreQ.isNotEmpty) return; // 1 letra: esperar más texto
      setState(() => filtering = true);
      _busquedaServer = false;
      List<Producto> filtrados = List.from(productos);

      String nombre = filtroNombreController.text.trim().toLowerCase();
      String categoria = filtroCategoriaController.text.trim().toLowerCase();

      if (nombre.isNotEmpty) {
        filtrados = filtrados
            .where((prod) => prod.nombre.toLowerCase().contains(nombre))
            .toList();
      }
      if (categoria.isNotEmpty) {
        filtrados = filtrados.where((prod) {
          String cat = "";
          if (prod.categoria is Map && prod.categoria != null) {
            cat = prod.categoria['nombre'] ?? "";
          } else if (prod.categoria is String) {
            cat = prod.categoria;
          }
          return cat.toLowerCase() == categoria.toLowerCase();
        }).toList();
      }

      if (_selectedCategoryFilter != null) {
        filtrados = filtrados.where((prod) {
          final catId = prod.categoria is Map ? prod.categoria['id'] : null;
          return catId == _selectedCategoryFilter;
        }).toList();
      }

      setState(() {
        productosFiltrados = filtrados;
        filtering = false;
      });
    });
  }

  // =========================================================
  // 3. LÓGICA DE PROMOCIONES Y PRECIOS
  // =========================================================
  double calcularPrecioFinal(Producto producto) {
    double precioFinal = producto.precioVenta;
    if (producto.promociones != null && producto.promociones!.isNotEmpty) {
      DateTime ahora = DateTime.now();
      var promocionesActivas = producto.promociones!.where((promo) {
        DateTime fechaInicio = DateTime.parse(promo['fecha_inicio']);
        DateTime fechaFin = DateTime.parse(promo['fecha_fin']);
        return ahora.isAfter(fechaInicio) && ahora.isBefore(fechaFin);
      }).toList();
      if (promocionesActivas.isNotEmpty) {
        var promo = promocionesActivas.first;
        if (promo['tipo'] == "descuento") {
          precioFinal -= (precioFinal * double.parse(promo['valor'].toString())) / 100;
        }
      }
    }
    return precioFinal;
  }

  bool tiene2x1(Producto producto) {
    if (producto.promociones != null && producto.promociones!.isNotEmpty) {
      DateTime ahora = DateTime.now();
      return producto.promociones!.any((promo) {
        DateTime fechaInicio = DateTime.parse(promo['fecha_inicio']);
        DateTime fechaFin = DateTime.parse(promo['fecha_fin']);
        return promo['tipo'] == "2x1" &&
            ahora.isAfter(fechaInicio) &&
            ahora.isBefore(fechaFin);
      });
    }
    return false;
  }

  // =========================================================
  // 4. AGREGAR PRODUCTO AL CARRITO POR CÓDIGO
  // =========================================================
  Future<void> buscarProducto(String codigo) async {
    String codigoUpper = codigo.toUpperCase();

    // Índice O(1) en memoria (barras + alternativos), luego remoto.
    Producto? producto = _indiceBarras[codigoUpper];
    if (producto == null) {
      producto = productos.firstWhereOrNull((p) {
        bool matchBarra = p.codigoBarras.toUpperCase() == codigoUpper;
        bool matchAlternativo = p.codigos?.any((c) => c.codigo.toUpperCase() == codigoUpper) ?? false;
        return matchBarra || matchAlternativo;
      });
    }

    // Si no se encuentra localmente, intentar con el servicio (por si acaso)
    if (producto == null) {
      try {
        producto = await _productoService.buscarProductoPorCodigo(codigoUpper);
      } catch (e) {
        print("Error buscando en API: $e");
      }
    }

    if (producto != null) {
      agregarProductoAlCarrito(producto);
    } else {
      if (!mounted) return;
      _mostrarSheetCodigoNoEncontrado(codigoUpper);
    }
  }

  /// Entrada del lector continuo: cooldown + feedback + lookup sin bloquear.
  Future<void> onCodigoEscaneado(String raw) async {
    final codigo = raw.trim().toUpperCase();
    if (!ScannerCooldown.esValido(codigo)) return;
    if (_cooldown.esDuplicado(codigo)) return;
    debugPrint('[scanner] detectado $codigo');
    // Feedback inmediato (<100ms, sin esperar red).
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    _scanFlash.value = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      _scanFlash.value = false;
    });

    final t0 = DateTime.now();
    Producto? producto = _indiceBarras[codigo];
    var origen = 'local';
    if (producto == null) {
      try {
        producto =
            await _productoService.buscarProductoPorCodigo(codigo);
        origen = 'remoto';
      } catch (_) {}
    }
    debugPrint('[scanner] lookup codigo=$codigo hit=$origen '
        'ms=${DateTime.now().difference(t0).inMilliseconds}');
    if (!mounted) return;
    if (producto == null) {
      _mostrarSheetCodigoNoEncontrado(codigo);
      return;
    }
    // Sucursal distinta o sin stock: avisar sin detener el lector.
    if (_selectedSucursal != null &&
        producto.sucursal?['id'] != _selectedSucursal) {
      _showBranchWarning(producto);
      return;
    }
    agregarProductoAlCarrito(producto);
  }

  void _mostrarSheetCodigoNoEncontrado(String codigo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código no encontrado',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SelectableText(codigo,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(LineIcons.search),
                title: const Text('Buscar por nombre'),
                onTap: () {
                  Navigator.pop(ctx);
                  filtroNombreController.text = '';
                },
              ),
              ListTile(
                leading: const Icon(LineIcons.timesCircle),
                title: const Text('Descartar'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Agrega (o suma +1) un producto al carrito. Fuente única para lector,
  /// búsqueda manual y código de barras.
  void agregarProductoAlCarrito(Producto producto) {
    // Verificar si el producto pertenece a la sucursal seleccionada
    if (_selectedSucursal != null &&
        producto.sucursal?['id'] != _selectedSucursal) {
      if (!mounted) return;
      _showBranchWarning(producto);
      return;
    }

    final idx = _cartIndex[producto.id];
    int cantidadIncremento = tiene2x1(producto) ? 2 : 1;
    if (idx != null && idx < carrito.length && carrito[idx]['id'] == producto.id) {
      carrito[idx]['cantidad'] =
          (carrito[idx]['cantidad'] ?? 0) + cantidadIncremento;
      if (mounted) setState(() {});
    } else {
      _setCarrito([
        ...carrito,
        {
          'id': producto.id,
          'nombre': producto.nombre,
          'codigo_barras': producto.codigoBarras,
          'imagen': producto.imagen,
          'precio_venta': producto.precioVenta,
          'costo': producto.costo,
          'stock': producto.stock,
          'promociones': producto.promociones,
          'categoria': producto.categoria,
          'cantidad': cantidadIncremento,
          'descuento': 0.0,
        }
      ]);
      if (mounted) setState(() {});
    }

    codigoBarras = "";
    barcodeController.clear();
    if (mounted && barcodeFocus.context != null) {
      FocusScope.of(context).requestFocus(barcodeFocus);
    }

    if (!mounted) return;
    _showAddToCartFeedback(context, producto.nombre);
  }

  void handleBarcodeChange(String value) {
    setState(() {
      codigoBarras = value.toUpperCase();
    });
    if (codigoBarras.length >= 2) {
      buscarProducto(codigoBarras);
    }
  }

  // =========================================================
  // 5. GESTIÓN DEL CARRITO
  // =========================================================
  void eliminarProductoDelCarrito(int productoId) {
    _setCarrito(
        carrito.where((item) => item['id'] != productoId).toList());
    setState(() {});
  }

  void aplicarDescuento(int productoId, double descuento) {
    setState(() {
      carrito = carrito.map((item) {
        if (item['id'] == productoId) {
          item['descuento'] = descuento;
        }
        return item;
      }).toList();
    });
  }

  double calcularTotal() {
    double total = 0.0;
    for (var item in carrito) {
      final p = Producto(
        id: item['id'],
        nombre: item['nombre'],
        codigoBarras: item['codigo_barras'],
        imagen: item['imagen'],
        precioVenta: item['precio_venta'],
        costo: item['costo'],
        stock: item['stock'],
        promociones: item['promociones'],
        categoria: item['categoria'],
      );

      double precioFinal = calcularPrecioFinal(p);
      double precioConDescuento = precioFinal - (item['descuento'] ?? 0.0);
      int qty = item['cantidad'] ?? 0;
      bool es2x1 = tiene2x1(p);
      double totalProducto = es2x1
          ? precioConDescuento * ((qty / 2).ceil())
          : precioConDescuento * qty;
      total += totalProducto;
    }
    return total;
  }

  // =========================================================
  // 6. GESTIÓN DE CLIENTES
  // =========================================================
  void handleNoReceiptChange(bool value) {
    setState(() {
      noReceipt = value;
    });
    if (noReceipt) {
      ciController.text = "0";
      nombreClienteController.text = "";
      cliente = null;
      if (!mounted) return;
      showTopSnackBar(
        Overlay.of(context)!,
        CustomSnackBar.info(
          message: "La venta se registrará sin asociar datos del cliente.",
        ),
      );
    } else {
      barcodeController.clear();
      FocusScope.of(context).requestFocus(barcodeFocus);
      ciController.text = "";
      nombreClienteController.text = "";
    }
  }

  Future<void> handleBuscarCliente() async {
    if (noReceipt) return;
    String ci = ciController.text.trim();
    if (ci.isEmpty || ci == "0") {
      if (!mounted) return;
      showTopSnackBar(
        Overlay.of(context)!,
        CustomSnackBar.info(
          message: "Por favor, ingresa un CI válido del cliente.",
        ),
      );
      return;
    }
    setState(() => loadingCliente = true);
    setState(() => loadingCliente = true);
    try {
      final response = await ApiService().dio.get('${getApiUrl('clientes')}?ci=$ci');
      if (!mounted) return;

      if (response.data != null && (response.data as Map).isNotEmpty) {
        setState(() {
          cliente = Cliente.fromJson(response.data);
          nombreClienteController.text = cliente!.nombreCompleto;
        });
        showTopSnackBar(
          Overlay.of(context)!,
          CustomSnackBar.success(
            message: "${cliente!.nombreCompleto} ha sido encontrado.",
          ),
        );
      } else {
        setState(() {
          cliente = null;
        });
        nombreClienteController.text = "";
        showTopSnackBar(
          Overlay.of(context)!,
          CustomSnackBar.info(
            message: "Cliente no encontrado, ingresa los datos manualmente.",
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        Overlay.of(context)!,
        CustomSnackBar.error(
          message: "El cliente no existe.",
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => loadingCliente = false);
    }
  }

  // =========================================================
  // 7. FINALIZAR VENTA / RESUMEN
  // =========================================================
  void handleFinalizarVenta() {
    setState(() {
      isResumenOpened = true;
    });
    // Pausar lector durante el cobro (ahorro batería + no sumar de más).
    _scannerPausado = true;
    unawaited(_pausarScanner('for checkout'));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return SalesSummaryModal(
            scrollController: scrollController,
            carrito: carrito,
            clienteActual: cliente,
            initialNoReceipt: noReceipt,
            ciController: ciController,
            nombreClienteController: nombreClienteController,
            montoEntregadoController: montoEntregadoController,
            calcularTotalCallback: calcularTotal,
            onNoReceiptChanged: (value) {
              handleNoReceiptChange(value);
            },
            onBuscarCliente: handleBuscarCliente,
            onMontoEntregadoChanged: (value) {
              actualizarCambio(value);
            },
            onConfirmarVenta: () async {
              await confirmarVenta();
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            onCancelarVenta: ({bool cerrarModal = true}) {
              cancelarVenta(cerrarModal: cerrarModal);
            },
            onItemCantidadChanged: (item, nuevaCantidad) {
              setState(() {
                final index = carrito.indexWhere((i) => i['id'] == item['id']);
                if (index != -1) {
                  carrito[index]['cantidad'] = nuevaCantidad;
                }
              });
            },
            onEliminarItem: (item) {
              setState(() {
                carrito.removeWhere((i) => i['id'] == item['id']);
                _rebuildCartIndex();
              });
            },
            initialMontoEntregado: montoEntregado,
            initialCambio: cambio,
            isSaving: saving,
            onVentaDetailsChanged: (gemas, tipo, qr, staffId, staffDiscount, staffName) {
              setState(() {
                gemasVenta = gemas;
                tipoPagoVenta = tipo;
                montoQRVenta = qr;
                idUsuarioPersonalVenta = staffId;
                descuentoPersonalVenta = staffDiscount;
                nombrePersonalVenta = staffName;
              });
            },
          );
        },
      ),
    ).then((_) {
      setState(() {
        isResumenOpened = false;
      });
      // Reanudar lector al volver del cobro.
      _scannerPausado = false;
      unawaited(_reanudarScanner());
    });
  }

  void cancelarVenta({bool cerrarModal = true}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("¿Cancelar venta?"),
        content: const Text("Se perderán todos los productos del carrito."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (cerrarModal && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              setState(() {
                carrito.clear();
                _rebuildCartIndex();
                cliente = null;
                noReceipt = false;
                montoEntregado = 0.0;
                cambio = 0.0;
                ciController.clear();
                nombreClienteController.clear();
                montoEntregadoController.clear();
                nombrePersonalVenta = null;
                isResumenOpened = false;
              });
              showTopSnackBar(
                Overlay.of(context)!,
                CustomSnackBar.info(
                  message: "Venta cancelada",
                  backgroundColor: Colors.grey[700]!,
                ),
              );
            },
            child: Text(
              "Sí",
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOGICA DE CAJA
  // =========================================================
  Future<void> _fetchEstadoCaja() async {
     if (_selectedSucursal == null) return;
     try {
       final userProvider = Provider.of<UserProvider>(context, listen: false);
       final response = await userProvider.get('${getApiUrl('cajas')}/status', queryParameters: {
         'id_sucursal': _selectedSucursal
       });
       
       if (mounted) {
         setState(() {
           _estadoCaja = response.data['estado'];
           if (_estadoCaja == 'abierta' && response.data['caja'] != null) {
             _idCajaActiva = response.data['caja']['id'];
           } else {
             _idCajaActiva = null;
           }
         });
       }
     } catch(e) {
       print('Error fetching caja: $e');
       if(mounted) setState(() => _idCajaActiva = null);
     }
  }

  Future<void> confirmarVenta() async {
    if (carrito.isEmpty) return;
    // Lock anti-doble envío (doble toque no genera 2 folios).
    if (_requestLock || saving) return;
    _requestLock = true;

    // Estado de caja fresco al confirmar (no el del arranque: la sucursal
    // del provider puede llegar tarde y la caja pudo abrirse en otro equipo).
    await _fetchEstadoCaja();
    if (!mounted) {
      _requestLock = false;
      return;
    }

    if (_idCajaActiva == null || _estadoCaja != 'abierta') {
      showTopSnackBar(
        Overlay.of(context)!,
        CustomSnackBar.error(message: "No hay una caja abierta en esta sucursal. Debe abrir caja para vender.")
      );
      _requestLock = false;
      return;
    }

    setState(() => saving = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final id_usuario = userProvider.userId;
    final id_sucursal = userProvider.branchId;

    // Verificar que existan los datos de usuario y sucursal
    if (id_usuario == null || id_sucursal == null) {
      showTopSnackBar(
        Overlay.of(context)!,
        CustomSnackBar.error(message: "Datos de usuario o sucursal no disponibles. Por favor inicia sesión.")
      );
      setState(() => saving = false);
      _requestLock = false;
      return;
    }

    // Asegurarnos de que todos los valores numéricos sean del tipo correcto
    Map<String, dynamic> ventaDataPayload = {
      'id_cliente': noReceipt ? 0 : (cliente != null ? cliente!.id : 0),
      'id_usuario': id_usuario,
      'id_sucursal': id_sucursal,
      'id_caja_activa': _idCajaActiva,
      'detalles': carrito.map((item) {
        // Extraer valores básicos con manejo seguro de tipos
        int productoId = item['id'] is int ? item['id'] : int.parse(item['id'].toString());
        
        // Precio de venta y costo deben ser números
        double precioVenta = 0.0;
        if (item['precio_venta'] != null) {
          precioVenta = item['precio_venta'] is double 
              ? item['precio_venta'] 
              : double.parse(item['precio_venta'].toString());
        }
        
        double costo = 0.0;
        if (item['costo'] != null) {
          costo = item['costo'] is double 
              ? item['costo'] 
              : double.parse(item['costo'].toString());
        }
        
        // Recrear el objeto Producto con valores seguros
        final p = Producto(
          id: productoId,
          nombre: item['nombre'] ?? 'Sin nombre',
          codigoBarras: item['codigo_barras'] ?? '',
          imagen: item['imagen'] ?? '',
          precioVenta: precioVenta,
          costo: costo,
          stock: item['stock'] is int ? item['stock'] : int.parse(item['stock'].toString()),
          promociones: item['promociones'],
          categoria: item['categoria'],
        );
        
        // Calcular precio con manejo seguro
        double precioFinal = calcularPrecioFinal(p);
        double descuento = 0.0;
        if (item['descuento'] != null) {
          if (item['descuento'] is String) {
            descuento = double.tryParse(item['descuento']) ?? 0.0;
          } else {
            descuento = (item['descuento'] as num).toDouble();
          }
        }
        
        double precioConDescuento = precioFinal - descuento;
        
        // Manejo seguro de la cantidad
        int qty = 1; // Por defecto al menos 1
        if (item['cantidad'] != null) {
          if (item['cantidad'] is String) {
            qty = int.tryParse(item['cantidad']) ?? 1;
          } else {
            qty = (item['cantidad'] as num).toInt();
          }
        }
        
        // Calcular subtotal con manejo seguro
        bool es2x1 = tiene2x1(p);
        double subtotal = es2x1
            ? precioConDescuento * ((qty / 2).ceil())
            : precioConDescuento * qty;
        
        // Construir el payload del detalle con los valores correctos
        return {
          'producto_id': productoId,
          'cantidad': qty,
          'precio_unitario': precioConDescuento,
          'subtotal': subtotal,
          'descuento': descuento,
        };
      }).toList(),
      'monto_total': calcularTotal(),
      'gemas': gemasVenta,
      'descuento_personal': descuentoPersonalVenta,
      'id_usuario_personal': idUsuarioPersonalVenta,
      'monto_qr': montoQRVenta,
      'tipo_pago': tipoPagoVenta,
      'fecha': DateTime.now().toIso8601String(),
      'vendedor': userProvider.user.containsKey('nombre') ? userProvider.user['nombre'] : 'Vendedor',
    };

    // El resto de la lógica para crear un cliente si es necesario
    if (!noReceipt && cliente == null) {
      String nombreCompleto = nombreClienteController.text.trim();
      String ci = ciController.text.trim();
      if (nombreCompleto.isEmpty || ci.isEmpty || ci == "0") {
        if (!mounted) return;
        showTopSnackBar(Overlay.of(context)!, CustomSnackBar.info(message: "Por favor completa todos los campos del cliente"));
        setState(() => saving = false);
        _requestLock = false;
        return;
      }
      try {
        final response = await ApiService().dio.post(getApiUrl('clientes'), data: {
          'nombre_completo': nombreCompleto,
          'ci': ci.toUpperCase(),
        });
        if (!mounted) return;
        ventaDataPayload['id_cliente'] = response.data['id_cliente'];
        cliente = Cliente(id: response.data['id_cliente'], nombreCompleto: nombreCompleto, ci: ci);
      } catch (e) {
        if (e is DioError && e.response != null && e.response!.data['error'] == "El CI ya está registrado.") {
          try {
            final existingClienteResponse = await ApiService().dio.get('${getApiUrl('clientes')}?ci=${ci.toUpperCase()}');
            if (!mounted) return;
            if (existingClienteResponse.data != null && (existingClienteResponse.data as Map).isNotEmpty) {
              ventaDataPayload['id_cliente'] = existingClienteResponse.data['id_cliente'];
              cliente = Cliente.fromJson(existingClienteResponse.data);
            } else {
              if (!mounted) return;
              showTopSnackBar(Overlay.of(context)!, CustomSnackBar.error(message: "Cliente con CI duplicado no encontrado tras error."));
              setState(() => saving = false);
              _requestLock = false;
              return;
            }
          } catch (e2) {
            if (!mounted) return;
            showTopSnackBar(Overlay.of(context)!, CustomSnackBar.error(message: "Error al buscar cliente existente con CI duplicado."));
            setState(() => saving = false);
            _requestLock = false;
            return;
          }
        } else {
          if (!mounted) return;
          showTopSnackBar(Overlay.of(context)!, CustomSnackBar.error(message: "Error al crear el nuevo cliente."));
          setState(() => saving = false);
          _requestLock = false;
          return;
        }
      }
    }

    try {
      final responseVenta = await ApiService().dio.post(getApiUrl('ventas'), data: ventaDataPayload);
      if (!mounted) return;

      final Map<String, dynamic> ventaRealizadaData = responseVenta.data;
      if (nombrePersonalVenta != null) {
        ventaRealizadaData['nombre_personal'] = nombrePersonalVenta;
      }
      final List<dynamic> detallesVentaRealizada = ventaRealizadaData['detalles'] ?? [];
      final Cliente? clienteParaRecibo = noReceipt ? null : cliente;

      showTopSnackBar(Overlay.of(context)!, CustomSnackBar.success(message: "Venta registrada exitosamente."));
      _mostrarExitoVenta(total, carrito.length);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      try {
        await PrinterService.printReciboEpson(
          ventaRealizadaData,
          detallesVentaRealizada,
          clienteParaRecibo?.toJson(),
          noReceipt,
          montoEntregado,
          cambio
        );
      } catch (printError) {
        // La venta YA quedó registrada: la impresora (127.0.0.1:8009) es
        // opcional. No mostrar como error de venta, solo aviso informativo.
        debugPrint('[venta] recibo no impreso (no bloquea): $printError');
        if (mounted) {
          showTopSnackBar(
              Overlay.of(context)!,
              CustomSnackBar.info(
                  message: "Venta registrada. Impresora no disponible."));
        }
      }

      setState(() {
        carrito.clear();
        _rebuildCartIndex();
        ciController.clear();
        nombreClienteController.clear();
        montoEntregadoController.clear();
        montoEntregado = 0.0;
        cambio = 0.0;
        gemasVenta = 0.0;
        descuentoPersonalVenta = 0.0;
        idUsuarioPersonalVenta = null;
        nombrePersonalVenta = null;
        montoQRVenta = 0.0;
        tipoPagoVenta = 'efectivo';
        isResumenOpened = false;
      });
      // Verificar si el widget está montado y el FocusNode tiene contexto
      if (mounted && barcodeFocus.context != null) {
        FocusScope.of(context).requestFocus(barcodeFocus);
      }
      fetchProductos();

    } catch (e) {
      if (!mounted) return;
      String errorMessage = "Ups! Error al registrar la venta.";
      if (e is DioError && e.response?.data is Map && e.response!.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else if (e is DioError && e.response?.data is Map && e.response!.data['error'] != null) {
        errorMessage = e.response!.data['error'];
      }
      showTopSnackBar(Overlay.of(context)!, CustomSnackBar.error(message: errorMessage));
    } finally {
      if (!mounted) return;
      _requestLock = false;
      setState(() => saving = false);
    }
  }

  // =========================================================
  // 8. CALCULAR CAMBIO
  // =========================================================
  void actualizarCambio(String value) {
    double monto = 0.0;
    if (value.isNotEmpty) {
      try {
        monto = double.parse(value);
      } catch (e) {
        print('Error al convertir monto: $e');
        monto = 0.0;
      }
    }
    
    setState(() {
      montoEntregado = monto;
      double totalVenta = calcularTotal();
      cambio = montoEntregado >= (totalVenta - descuentoPersonalVenta) ? montoEntregado - (totalVenta - descuentoPersonalVenta) : 0.0;
    });
  }

  /// Feedback visual al agregar un producto al carrito
  void _showAddToCartFeedback(BuildContext context, String productName) {
    showTopSnackBar(
      Overlay.of(context)!,
      CustomSnackBar.success(
        message: "$productName ha sido agregado al carrito.",
        backgroundColor: Colors.pink[700]!,
      ),
    );
  }

  /// Indicador de carga
  Widget _buildLoadingIndicator() {
    return Center(
      child: SpinKitFadingCircle(
        color: kPrimaryColor,
        size: 50.0,
      ),
    );
  }

  void _showBranchWarning(Producto producto) {
    final sucursalDelProducto = producto.sucursal?['nombre'] ?? 'Otra Sucursal';
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final sucursalActual = userProvider.branch?['nombre'] ?? 'Sucursal Actual';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: kWarningColor, size: 28),
            SizedBox(width: 10.w),
            Text("Producto en otra Sucursal", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "El producto \"${producto.nombre}\" no está registrado en $sucursalActual.",
              style: GoogleFonts.poppins(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kWarningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kWarningColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(LineIcons.store, color: kWarningColor, size: 20),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      "Disponible en: $sucursalDelProducto (Stock: ${producto.stock})",
                      style: GoogleFonts.poppins(color: kWarningColor.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              "¿Deseas cambiar a $sucursalDelProducto para realizar la venta?",
              style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Cambiar de sucursal
              setState(() {
                _selectedSucursal = producto.sucursal?['id'];
                userProvider.updateBranch(producto.sucursal!);
              });
              fetchProductos(); // Recargar
              buscarProducto(producto.codigoBarras); // Reintentar agregar
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("CAMBIAR Y AGREGAR", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  Widget _buildSliverAppBar() {
    final userProvider = Provider.of<UserProvider>(context);
    final sucursalName = userProvider.branch?['nombre'] ?? 'Seleccione Sucursal';

    return SliverAppBar(
      backgroundColor: kBackgroundLight,
      expandedHeight: 170.h,
      floating: false,
      pinned: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            gradient: LinearGradient(
              colors: [const Color(0xFFE879F9), const Color(0xFFC026D3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
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
              
              // Content like Productos
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 50.h, 24.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ventas",
                      style: GoogleFonts.poppins(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _showSucursalSelectionModal();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LineIcons.store, color: Colors.white.withOpacity(0.9), size: 14.sp),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              sucursalName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                             Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.9), size: 14.sp),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60.h),
        child: Container(
          height: 60.h,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          child: _buildSearchBar(context),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final sucursalName = userProvider.branch?['nombre'] ?? 'Sucursal';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: filtroNombreController,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar productos por nombre...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13.sp),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16.w, right: 8.w),
                  child: Icon(LineIcons.search, color: kPrimaryColor, size: 22),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ),
          IconButton(
            icon: Icon(LineIcons.barcode, color: Colors.grey[400], size: 22),
            onPressed: () async {
              final code = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              );
              if (code != null && code.isNotEmpty) {
                setState(() => barcodeController.text = code);
                buscarProducto(code);
              }
            },
            padding: EdgeInsets.only(right: 12.w),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(Set<String> categoryNames, List<dynamic> categoriesRaw) {
    if (categoryNames.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    // Convert Set<String> to a list we can work with and map to IDs
    final List<Map<String, dynamic>> categoriesList = [];
    for (var catName in categoryNames) {
       final raw = categoriesRaw.firstWhereOrNull((c) => c['nombre'] == catName);
       if (raw != null) categoriesList.add(raw);
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 48.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: categoriesList.length + 1,
          itemBuilder: (context, index) {
            String label;
            bool isSelected;
            VoidCallback onTap;

            if (index == 0) {
              label = 'Todas';
              isSelected = _selectedCategoryFilter == null;
              onTap = () {
                 if (!isSelected) {
                    setState(() {
                      _selectedCategoryFilter = null;
                      _onFiltroChanged();
                    });
                 }
              };
            } else {
              final cat = categoriesList[index - 1];
              label = cat['nombre'] ?? '';
              final catId = cat['id'];
              isSelected = _selectedCategoryFilter == catId;
              onTap = () {
                 if (!isSelected) {
                   setState(() {
                      _selectedCategoryFilter = catId;
                      _onFiltroChanged();
                    });
                 } else {
                    setState(() {
                      _selectedCategoryFilter = null;
                      _onFiltroChanged();
                    });
                 }
              };
            }

            return Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.grey.shade200,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: kPrimaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // Método para mostrar configuración de impresora
  // =========================================================
  void _showPrinterSettings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrinterSettings(onClose: () {
      Navigator.of(context).pop();
    })));
  }

  // =========================================================
  // RENDER PRINCIPAL
  // =========================================================
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    
    // Categorías únicas y mapeo para chips
    Set<String> categoryNames = {};
    List<dynamic> categoriesRaw = [];
    for (var prod in productos) {
      if (prod.categoria != null) {
        String name = "";
        if (prod.categoria is Map) {
          name = prod.categoria['nombre'] ?? "";
          if (!categoryNames.contains(name)) {
            categoryNames.add(name);
            categoriesRaw.add(prod.categoria);
          }
        } else if (prod.categoria is String) {
          name = prod.categoria;
          if (!categoryNames.contains(name)) {
            categoryNames.add(name);
            categoriesRaw.add({'nombre': name, 'id': name});
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: kBackgroundLight,
      body: Stack(
        children: [
          CustomScrollView(
        controller: _ventasScrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),

          SliverToBoxAdapter(child: SizedBox(height: 20.h)),

          // Tira lector continuo (supermercado): siempre visible, no navega.
          if (_scannerController != null)
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: ContinuousScannerStrip(
                  controller: _scannerController!,
                  flashOk: _scanFlash,
                  onCodigoDetectado: onCodigoEscaneado,
                  onPermisoDenegado: () {
                    if (!mounted) return;
                    showTopSnackBar(
                      Overlay.of(context)!,
                      CustomSnackBar.info(
                        message: "Cámara no disponible: usa búsqueda manual.",
                      ),
                    );
                  },
                ),
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
                
                _buildCategoryChips(categoryNames, categoriesRaw),
                
                SliverToBoxAdapter(child: SizedBox(height: 10.h)),

                // Lista de productos corregida para slivers
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: _buildProductGridSliver(),
                ),
                
                SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
          ),
          // Loader bloqueante mientras se envía la venta al backend.
          if (saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 28.w, vertical: 22.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SpinKitFadingCircle(
                            color: Color(0xFFC026D3), size: 44),
                        SizedBox(height: 12.h),
                        Text('Enviando venta...',
                            style: GoogleFonts.poppins(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF3B0764))),
                        Text('No cierres la app',
                            style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Éxito visible 1.8s tras registrar (el modal ya se cerró).
          if (_mostrarExito)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 40.w),
                    padding: EdgeInsets.symmetric(
                        horizontal: 28.w, vertical: 24.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64.w,
                          height: 64.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 36),
                        ),
                        SizedBox(height: 12.h),
                        Text('¡Venta registrada!',
                            style: GoogleFonts.poppins(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3B0764))),
                        SizedBox(height: 4.h),
                        Text(
                          'Bs. ${_exitoTotal.toStringAsFixed(2)} · $_exitoItems items',
                          style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildModernFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProductGridSliver() {
    final crossAxisCount = ResponsiveValue<int>(
      context,
      defaultValue: 2,
      conditionalValues: [
        Condition.smallerThan(name: MOBILE, value: 1),
        Condition.equals(name: MOBILE, value: 2),
        Condition.largerThan(name: MOBILE, value: 3),
        Condition.largerThan(name: TABLET, value: 4),
        Condition.largerThan(name: DESKTOP, value: 6),
      ],
    ).value!;

    if (loading) {
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 0.70,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SkeletonProductCard(),
          childCount: 6, // Show 6 skeletons
        ),
      );
    }

    if (productosFiltrados.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LineIcons.box, size: 64, color: Colors.grey.shade300),
              SizedBox(height: 16.h),
              Text(
                'No se encontraron productos',
                style: GoogleFonts.poppins(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16.h,
        crossAxisSpacing: 16.w,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final producto = productosFiltrados[index];
          return SalesProductCard(
            producto: producto,
            onTap: () => buscarProducto(producto.codigoBarras),
            precioFinal: calcularPrecioFinal(producto),
            es2x1: tiene2x1(producto),
            cantidadEnCarrito: carrito.firstWhereOrNull((item) => item['id'] == producto.id)?['cantidad'] ?? 0,
          );
        },
        childCount: productosFiltrados.length,
      ),
    );
  }

  Widget _buildModernFAB() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: "settings",
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: _showPrinterSettings,
            child: Icon(LineIcons.print, color: kDarkPurple),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: carrito.isEmpty ? null : handleFinalizarVenta,
                  child: Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: carrito.isEmpty 
                            ? [Colors.grey[400]!, Colors.grey[500]!]
                            : [kPrimaryColor, kDarkPurple],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (carrito.isEmpty ? Colors.grey : kPrimaryColor).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isResumenOpened ? LineIcons.fileInvoice : LineIcons.checkCircle,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            isResumenOpened ? "VER RESUMEN" : "FINALIZAR VENTA",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (carrito.isNotEmpty)
                  Positioned(
                    right: -5,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kErrorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: kErrorColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        minWidth: 28.w,
                        minHeight: 28.w,
                      ),
                      child: Center(
                        child: Text(
                          '${carrito.length}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra un bottom sheet con la lista de categorías
  void _showCategoriesModal(BuildContext context, Set<String> categories) {
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
                      "Seleccionar Categoría",
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  children: [
                    ListTile(
                      leading: Icon(LineIcons.list, color: kPrimaryColor),
                      title: Text("Todas las categorías", style: GoogleFonts.poppins()),
                      onTap: () {
                        filtroCategoriaController.clear();
                        Navigator.pop(context);
                        _onFiltroChanged();
                      },
                    ),
                    ...categories.map((cat) {
                      return ListTile(
                        leading: Icon(LineIcons.tag, color: kSecondaryColor),
                        title: Text(cat, style: GoogleFonts.poppins()),
                        onTap: () {
                          filtroCategoriaController.text = cat;
                          Navigator.pop(context);
                          _onFiltroChanged();
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }
}
