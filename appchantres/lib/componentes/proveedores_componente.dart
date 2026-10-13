import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../api.dart';
import '../servicios/api_service.dart';

class ProveedoresComponente extends StatefulWidget {
  final Function onDataChanged;

  const ProveedoresComponente({
    Key? key,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _ProveedoresComponenteState createState() => _ProveedoresComponenteState();
}

class _ProveedoresComponenteState extends State<ProveedoresComponente> {
  final Dio _dio = ApiService().dio;
  List<dynamic> _proveedores = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _searchQuery = '';
  List<dynamic> _filteredProveedores = [];
  
  // Para el formulario
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _contactoController = TextEditingController();
  final _direccionController = TextEditingController();
  
  // Proveedor en edición
  Map<String, dynamic>? _proveedorEnEdicion;

  @override
  void initState() {
    super.initState();
    _fetchProveedores();
  }
  
  @override
  void dispose() {
    _nombreController.dispose();
    _contactoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchProveedores() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _dio.get(getApiUrl('proveedores'));
      if (!mounted) return;
      setState(() {
        _proveedores = response.data;
        _filtrarProveedores();
      });
    } catch (e) {
      _showErrorSnackBar('Error al cargar los proveedores');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _filtrarProveedores() {
    if (_searchQuery.isEmpty) {
      _filteredProveedores = List.from(_proveedores);
    } else {
      _filteredProveedores = _proveedores.where((proveedor) {
        final nombre = proveedor['nombre']?.toString().toLowerCase() ?? '';
        final contacto = proveedor['contacto']?.toString().toLowerCase() ?? '';
        return nombre.contains(_searchQuery.toLowerCase()) || 
               contacto.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }
  
  void _showErrorSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red)
    );
  }

  void _showSuccessSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green)
    );
  }
  
  void _mostrarFormularioProveedor(BuildContext context, {Map<String, dynamic>? proveedor}) {
    if (proveedor != null) {
      _proveedorEnEdicion = proveedor;
      _nombreController.text = proveedor['nombre'] ?? '';
      _contactoController.text = proveedor['contacto'] ?? '';
      _direccionController.text = proveedor['email'] ?? ''; // Usamos email como dirección
    } else {
      _proveedorEnEdicion = null;
      _nombreController.clear();
      _contactoController.clear();
      _direccionController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _buildFormularioProveedor(context),
      ),
    );
  }
  
  Widget _buildFormularioProveedor(BuildContext context) {
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
            // Barra superior con título y botón de cerrar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _proveedorEnEdicion == null ? 'Nuevo Proveedor' : 'Editar Proveedor',
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
                  // Nombre del proveedor
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Nombre del proveedor',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(LineIcons.building),
                    ),
                    validator: (value) => value?.isEmpty ?? true 
                        ? 'Ingrese el nombre del proveedor' 
                        : null,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Contacto
                  TextFormField(
                    controller: _contactoController,
                    decoration: InputDecoration(
                      labelText: 'Contacto',
                      hintText: 'Teléfono o contacto',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(LineIcons.phone),
                    ),
                    validator: (value) => value?.isEmpty ?? true 
                        ? 'Ingrese un contacto' 
                        : null,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Dirección (usando el campo email del backend)
                  TextFormField(
                    controller: _direccionController,
                    decoration: InputDecoration(
                      labelText: 'Dirección',
                      hintText: 'Dirección del proveedor',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(LineIcons.mapMarker),
                    ),
                    validator: (value) => value?.isEmpty ?? true 
                        ? 'Ingrese la dirección' 
                        : null,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            
            // Botones de acción
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
                      onPressed: _isSubmitting ? null : _guardarProveedor,
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
  
  Future<void> _guardarProveedor() async {
    if (_formKey.currentState?.validate() != true) return;
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final data = {
        'nombre': _nombreController.text,
        'contacto': _contactoController.text,
        'email': _direccionController.text, // Usamos email para la dirección
      };
      
      if (_proveedorEnEdicion != null) {
        await _dio.put(
          getApiUrl('proveedores/${_proveedorEnEdicion!['id']}'),
          data: data,
        );
        _showSuccessSnackBar('Proveedor actualizado correctamente');
      } else {
        await _dio.post(
          getApiUrl('proveedores'),
          data: data,
        );
        _showSuccessSnackBar('Proveedor creado correctamente');
      }
      
      if (!mounted) return;
      Navigator.pop(context);
      _fetchProveedores();
      widget.onDataChanged();
    } catch (e) {
      _showErrorSnackBar('Error al guardar el proveedor');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  Future<void> _eliminarProveedor(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar este proveedor?'),
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
        await _dio.delete(getApiUrl('proveedores/$id'));
        if (!mounted) return;
        _showSuccessSnackBar('Proveedor eliminado correctamente');
        _fetchProveedores();
        widget.onDataChanged();
      } catch (e) {
        _showErrorSnackBar('Error al eliminar el proveedor');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Encabezado con título y búsqueda
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Proveedores',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _mostrarFormularioProveedor(context),
                      icon: Icon(Icons.add),
                      label: Text('Nuevo'),
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
                SizedBox(height: 16),
                // Campo de búsqueda
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar proveedor',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filtrarProveedores();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de proveedores
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : _filteredProveedores.isEmpty
                    ? _buildEmptyState()
                    : _buildProveedoresLista(),
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
            height:
            80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
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
              LineIcons.userTie,
              size: 50,
              color: Colors.pink.shade500,
            ),
          ),
          SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No se encontraron proveedores' 
                : 'No hay proveedores registrados',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Prueba con otra búsqueda' 
                : 'Agrega tu primer proveedor',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormularioProveedor(context),
            icon: Icon(Icons.add),
            label: Text('Nuevo Proveedor'),
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
  
  Widget _buildProveedoresLista() {
    return ListView.builder(
      itemCount: _filteredProveedores.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final proveedor = _filteredProveedores[index];
        
        return Animate(
          effects: [FadeEffect(duration: Duration(milliseconds: 300), delay: Duration(milliseconds: index * 50))],
          child: Slidable(
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _mostrarFormularioProveedor(context, proveedor: proveedor),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: LineIcons.edit,
                  label: 'Editar',
                ),
                SlidableAction(
                  onPressed: (_) => _eliminarProveedor(proveedor['id']),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: LineIcons.trash,
                  label: 'Eliminar',
                ),
              ],
            ),
            child: Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Colors.pink.shade100,
                  child: Text(
                    (proveedor['nombre'] ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.pink.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  proveedor['nombre'] ?? 'Sin nombre',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LineIcons.phone, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(proveedor['contacto'] ?? 'Sin contacto'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LineIcons.mapMarker, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            proveedor['email'] ?? 'Sin dirección',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
