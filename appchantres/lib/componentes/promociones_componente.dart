import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../api.dart';
import '../servicios/api_service.dart';
import 'package:intl/date_symbol_data_local.dart';

class PromocionesComponente extends StatefulWidget {
  final List<dynamic> productos;
  final Function onDataChanged;

  const PromocionesComponente({
    Key? key,
    required this.productos,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<PromocionesComponente> createState() => _PromocionesComponenteState();
}

class _PromocionesComponenteState extends State<PromocionesComponente> {
  final Dio _dio = ApiService().dio;
  List<dynamic> _promociones = [];
  List<dynamic> _selectedProductIds = [];
  List<dynamic> _localProductos = [];
  bool _isLoading = false;
  bool _isProductsLoading = false;
  bool _isSubmitting = false;
  bool _isProductSelectionModalVisible = false;
  String _searchQuery = '';

  final _formKey = GlobalKey<FormState>();
  final _tipoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _valorController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  Map<String, dynamic>? _promocionEnEdicion;

  @override
  void initState() {
    initializeDateFormatting('es_ES', null);
    super.initState();
    _fetchPromociones();
    _fetchProductos();
  }

  @override
  void dispose() {
    _tipoController.dispose();
    _descripcionController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromociones() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.get(getApiUrl('promociones'));
      if (!mounted) return;
      setState(() {
        _promociones = response.data;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al cargar las promociones');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchProductos() async {
    setState(() {
      _isProductsLoading = true;
    });

    try {
      final response = await _dio.get(getApiUrl('productos'));
      if (!mounted) return;
      setState(() {
        _localProductos = response.data;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al cargar los productos');
    } finally {
      if (mounted) {
        setState(() {
          _isProductsLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _mostrarFormularioPromocion(BuildContext context, {Map<String, dynamic>? promocion}) {
    if (promocion != null) {
      _promocionEnEdicion = promocion;
      _tipoController.text = promocion['tipo'] ?? '';
      _descripcionController.text = promocion['descripcion'] ?? '';
      _valorController.text = promocion['valor']?.toString() ?? '';
      _fechaInicio = promocion['fecha_inicio'] != null
          ? DateTime.parse(promocion['fecha_inicio'])
          : null;
      _fechaFin = promocion['fecha_fin'] != null
          ? DateTime.parse(promocion['fecha_fin'])
          : null;
      _selectedProductIds = List<dynamic>.from(promocion['productos'] ?? [])
          .map((p) => p['id']).toList();
    } else {
      _promocionEnEdicion = null;
      _tipoController.clear();
      _descripcionController.clear();
      _valorController.clear();
      _fechaInicio = null;
      _fechaFin = null;
      _selectedProductIds = [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _buildFormularioPromocion(context),
      ),
    );
  }

  List<dynamic> _getCurrentProductos() {
    if (_localProductos.isNotEmpty) {
      return _localProductos;
    }
    return widget.productos;
  }

  List<dynamic> _filtrarProductos(String query) {
    if (query.isEmpty) {
      return _localProductos;
    }
    return _localProductos.where((producto) {
      final nombre = (producto['nombre'] ?? '').toString().toLowerCase();
      final codigo = (producto['codigo_barras'] ?? '').toString().toLowerCase();
      return nombre.contains(query.toLowerCase()) || codigo.contains(query.toLowerCase());
    }).toList();
  }

  Widget _buildFormularioPromocion(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _promocionEnEdicion == null ? 'Nueva Promoción' : 'Editar Promoción',
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

            Expanded(
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Tipo de Promoción',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: _tipoController.text.isNotEmpty ? _tipoController.text : null,
                    items: [
                      DropdownMenuItem(value: 'descuento', child: Text('Descuento')),
                      DropdownMenuItem(value: '2x1', child: Text('2x1')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _tipoController.text = value ?? '';
                        if (value == '2x1') {
                          _valorController.text = '0';
                        }
                      });
                    },
                    validator: (value) => value == null ? 'Seleccione un tipo' : null,
                  ),

                  SizedBox(height: 16),

                  TextFormField(
                    controller: _descripcionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(LineIcons.infoCircle),
                    ),
                    maxLines: 3,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Ingrese una descripción'
                        : null,
                  ),

                  SizedBox(height: 16),

                  if (_tipoController.text != '2x1')
                    TextFormField(
                      controller: _valorController,
                      decoration: InputDecoration(
                        labelText: 'Valor (%)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(LineIcons.percentage),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_tipoController.text == '2x1') return null;
                        if (value?.isEmpty ?? true) return 'Ingrese un valor';
                        final numero = double.tryParse(value!);
                        if (numero == null) return 'Ingrese un número válido';
                        if (numero <= 0 || numero > 100) return 'El valor debe estar entre 1 y 100';
                        return null;
                      },
                    ),

                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildFechaCaducidadField(
                          'Fecha Inicio',
                          _fechaInicio,
                          (fecha) => setState(() => _fechaInicio = fecha),
                        ),
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: _buildFechaCaducidadField(
                          'Fecha Fin',
                          _fechaFin,
                          (fecha) => setState(() => _fechaFin = fecha),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Productos en Promoción',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isProductSelectionModalVisible = true;
                          });
                          _mostrarSelectorProductos(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink.shade500,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          minimumSize: Size(40, 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LineIcons.shoppingBasket, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "${_selectedProductIds.length}",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  _selectedProductIds.isEmpty
                      ? Text(
                          'No se han seleccionado productos',
                          style: TextStyle(
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedProductIds.map((productId) {
                            final productoLocal = _localProductos.firstWhere(
                              (p) => p['id'] == productId,
                              orElse: () => null,
                            );

                            final productoWidget = widget.productos.firstWhere(
                              (p) => p['id'] == productId,
                              orElse: () => null,
                            );

                            final producto = productoLocal ?? productoWidget ?? {'nombre': 'Producto desconocido'};

                            return Chip(
                              label: Text(producto['nombre'] ?? 'Sin nombre'),
                              backgroundColor: Colors.blue.shade100,
                              deleteIcon: Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedProductIds.remove(productId);
                                });
                              },
                            );
                          }).toList(),
                        ),

                  SizedBox(height: 16),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _guardarPromocion,
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade500,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorProductos(BuildContext context) {
    final productosToShow = _getCurrentProductos();
    _searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredProductos = _filtrarProductos(_searchQuery);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade500,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seleccionar Productos',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          decoration: InputDecoration(
                            hintText: 'Buscar producto por nombre o código...',
                            prefixIcon: Icon(LineIcons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        SizedBox(height: 8),
                        Text(
                          "${filteredProductos.length} productos disponibles",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: filteredProductos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LineIcons.exclamationCircle, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No hay productos disponibles'
                                      : 'No se encontraron productos con "$_searchQuery"',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredProductos.length,
                            separatorBuilder: (context, index) => Divider(),
                            itemBuilder: (context, index) {
                              final producto = filteredProductos[index];
                              final isSelected = _selectedProductIds.contains(producto['id']);

                              return ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: producto['imagen'] != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: getImageUrl(producto['imagen']),
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(
                                              child: SpinKitPulse(color: Colors.pink, size: 20.0),
                                            ),
                                            errorWidget: (context, url, error) => const Icon(
                                              LineIcons.image,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          LineIcons.box,
                                          color: Colors.grey,
                                        ),
                                ),
                                title: Text(
                                  producto['nombre'] ?? 'Sin nombre',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Bs. ${producto['precio_venta'] ?? '0.00'}'),
                                trailing: IconButton(
                                  icon: Icon(
                                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                                    color: isSelected ? Colors.green : Colors.pink.shade500,
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedProductIds.remove(producto['id']);
                                        } else {
                                          _selectedProductIds.add(producto['id']);
                                        }
                                      });
                                    });
                                  },
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              );
                            },
                          ),
                  ),

                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total de productos seleccionados: ${_selectedProductIds.length}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              child: Text('Cancelar'),
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            ElevatedButton(
                              child: Text('Confirmar selección'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink.shade500,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
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
      ),
    );
  }

  Widget _buildFechaCaducidadField(String labelText, DateTime? fecha, Function(DateTime?) onDateSelected) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(LineIcons.calendar),
      ),
      controller: TextEditingController(
        text: fecha != null
            ? DateFormat('dd/MM/yyyy', 'es_ES').format(fecha)
            : '',
      ),
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: fecha ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(Duration(days: 365)),
          locale: const Locale('es', 'ES'),
        );
        if (selectedDate != null) {
          onDateSelected(selectedDate);
        }
      },
      validator: (value) => value?.isEmpty ?? true
          ? 'Seleccione una fecha'
          : null,
    );
  }

  Future<void> _guardarPromocion() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debe seleccionar al menos un producto')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'tipo': _tipoController.text,
        'descripcion': _descripcionController.text,
        'valor': _valorController.text,
        'fecha_inicio': DateFormat('yyyy-MM-dd').format(_fechaInicio!),
        'fecha_fin': DateFormat('yyyy-MM-dd').format(_fechaFin!),
        'id_productos': _selectedProductIds,
      };

      if (_promocionEnEdicion != null) {
        await _dio.put(
          getApiUrl('promociones/${_promocionEnEdicion!['id']}'),
          data: data,
        );
        _showSuccessSnackBar('Promoción actualizada correctamente');
      } else {
        await _dio.post(
          getApiUrl('promociones'),
          data: data,
        );
        _showSuccessSnackBar('Promoción creada correctamente');
      }

      if (!mounted) return;
      Navigator.pop(context);
      _fetchPromociones();
      widget.onDataChanged();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al guardar la promoción');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmarEliminarPromocion(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar esta promoción?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _dio.delete(getApiUrl('promociones/$id'));
        if (!mounted) return;
        _showSuccessSnackBar('Promoción eliminada correctamente');
        _fetchPromociones();
        widget.onDataChanged();
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Error al eliminar la promoción');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Promociones',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _mostrarFormularioPromocion(context),
                  icon: Icon(Icons.add),
                  label: Text('Nueva Promoción'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : _promociones.isEmpty
                    ? _buildEmptyState(
                        'No hay promociones',
                        'Crea una nueva promoción para tus productos',
                        LineIcons.tag,
                      )
                    : _buildPromocionesLista(),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.all(16),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: Colors.pink.shade500,
            ),
          ),
          SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormularioPromocion(context),
            icon: Icon(Icons.add),
            label: Text('Nueva Promoción'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade500,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromocionesLista() {
    return ListView.builder(
      itemCount: _promociones.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final promocion = _promociones[index];

        return Animate(
          effects: [FadeEffect(duration: Duration(milliseconds: 300), delay: Duration(milliseconds: index * 50))],
          child: Slidable(
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _mostrarFormularioPromocion(context, promocion: promocion),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: LineIcons.edit,
                  label: 'Editar',
                ),
                SlidableAction(
                  onPressed: (_) => _confirmarEliminarPromocion(promocion['id']),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: LineIcons.trash,
                  label: 'Eliminar',
                ),
              ],
            ),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade500,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            promocion['tipo'] == 'descuento'
                                ? 'Descuento ${promocion['valor']}%'
                                : '2x1',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        Spacer(),

                        Text(
                          '${DateFormat('dd/MM/yyyy').format(DateTime.parse(promocion['fecha_inicio']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(promocion['fecha_fin']))}',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    Text(
                      promocion['descripcion'] ?? '',
                      style: TextStyle(fontSize: 14),
                    ),

                    SizedBox(height: 12),

                    Row(
                      children: [
                        Icon(LineIcons.shoppingBasket, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          '${promocion['productos']?.length ?? 0} productos',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
