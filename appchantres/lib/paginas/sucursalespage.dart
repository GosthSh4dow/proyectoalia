import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:line_icons/line_icons.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:ui';
import '../api.dart';
import '../servicios/api_service.dart';

class SucursalesPage extends StatefulWidget {
  const SucursalesPage({Key? key}) : super(key: key);

  @override
  _SucursalesPageState createState() => _SucursalesPageState();
}

class _SucursalesPageState extends State<SucursalesPage> with SingleTickerProviderStateMixin {
  List<dynamic> sucursales = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredSucursales = [];
  
  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Colores corporativos (Purple Theme like Reportes)
  final Color primaryColor = const Color(0xFFC026D3);
  final Color secondaryColor = const Color(0xFFE879F9);
  final Color backgroundColor = const Color(0xFFFDF4FF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    fetchSucursales();
    _searchController.addListener(_filterSucursales);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterSucursales);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _filterSucursales() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredSucursales = List.from(sucursales);
      } else {
        _filteredSucursales = sucursales.where((sucursal) {
          final nombre = sucursal['nombre'].toString().toLowerCase();
          final direccion = sucursal['direccion']?.toString().toLowerCase() ?? '';
          return nombre.contains(query) || direccion.contains(query);
        }).toList();
      }
    });
  }

  Future<void> fetchSucursales() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService().dio.get(getApiUrl("sucursales"));
      if (response.statusCode == 200) {
        setState(() {
          sucursales = response.data;
          _filteredSucursales = List.from(sucursales);
        });
      } else {
        showTopNotification("Error", "Error al cargar las sucursales", false);
      }
    } catch (e) {
      showTopNotification("Error", "Error de conexión", false);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showTopNotification(String title, String message, bool success) {
    final snackBar = success
        ? CustomSnackBar.success(message: "$title\n$message")
        : CustomSnackBar.error(message: "$title\n$message");
    showTopSnackBar(Overlay.of(context)!, snackBar, displayDuration: const Duration(seconds: 2));
  }

  void showFormModal({Map<String, dynamic>? sucursal}) {
    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.9),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom
                ),
                child: SucursalForm(
                  sucursal: sucursal,
                  onSuccess: fetchSucursales,
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),
              ),
            ),
          ),
        );
      },
    );
  }

  void confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "¿Eliminar sucursal?",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Esta acción no se puede deshacer.",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancelar",
                style: GoogleFonts.poppins(),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await deleteSucursal(id);
              },
              child: Text(
                "Eliminar", 
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  Future<void> deleteSucursal(int id) async {
    try {
      final response = await ApiService().dio.delete(getApiUrl("sucursales/$id"));
      if (response.statusCode == 200) {
        fetchSucursales();
        showTopNotification("Éxito", "Sucursal eliminada correctamente", true);
      } else {
        showTopNotification("Error", "Error al eliminar la sucursal", false);
      }
    } catch (e) {
      showTopNotification("Error", "Error de conexión", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: _buildSearchBar(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _buildStatsGrid(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: isLoading
              ? SliverToBoxAdapter(
                  child: Center(
                    child: SpinKitFadingCircle(
                      color: primaryColor,
                      size: 50.0,
                    ),
                  ),
                )
              : _filteredSucursales.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : _buildSucursalesSliverList(),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 80)), // Bottom padding
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showFormModal(),
        backgroundColor: primaryColor,
        child: const Icon(LineIcons.plus),
        elevation: 4,
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: backgroundColor,
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28), // Hamburger Menu
        onPressed: () => Scaffold.of(context).openDrawer(), // Open Drawer
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            gradient: LinearGradient(
              colors: [secondaryColor, primaryColor],
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
              Positioned(
                bottom: -20,
                left: -20,
                child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sucursales',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Gestión de puntos de venta',
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Buscar sucursal...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          prefixIcon: Icon(LineIcons.search, color: primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    int total = _filteredSucursales.length;
    int activas = _filteredSucursales.where((s) => s['estado'] == 'activa').length;
    int inactivas = _filteredSucursales.where((s) => s['estado'] == 'inactiva').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatisticItem('$total', 'Total', LineIcons.building),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          _buildStatisticItem('$activas', 'Activas', LineIcons.checkCircle),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          _buildStatisticItem('$inactivas', 'Inactivas', LineIcons.timesCircle),
        ],
      ),
    );
  }
  
  Widget _buildStatisticItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            LineIcons.boxOpen, 
            size: 100,
            color: Colors.grey[300],
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2000.ms)
           .moveY(begin: 0, end: -10, duration: 2000.ms), // Breathing/Floating effect
           
          const SizedBox(height: 24),
          Text(
            'No hay sucursales encontradas',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn().slideY(begin: 0.5, duration: 500.ms),
          
          const SizedBox(height: 8),
          Text(
            'Intenta ajustar tu búsqueda o crea una nueva.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, duration: 500.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSucursalesSliverList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final sucursal = _filteredSucursales[index];
          return Animate(
            effects: [
              FadeEffect(
                delay: Duration(milliseconds: 50 * index),
                duration: const Duration(milliseconds: 300),
              ),
              SlideEffect(
                begin: const Offset(0.05, 0),
                end: const Offset(0, 0),
                delay: Duration(milliseconds: 50 * index),
                duration: const Duration(milliseconds: 300),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => showFormModal(sucursal: sucursal),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: sucursal['estado'] == 'activa' 
                                ? Colors.green.withOpacity(0.1) 
                                : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              LineIcons.building,
                              color: sucursal['estado'] == 'activa' ? Colors.green : Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sucursal['nombre'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(LineIcons.mapMarker, size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        sucursal['direccion'] ?? 'Sin dirección',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sucursal['estado'] == 'activa' 
                                ? Colors.green.withOpacity(0.1) 
                                : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              sucursal['estado'] == 'activa' ? 'Activa' : 'Inactiva',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sucursal['estado'] == 'activa' ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                             icon: Icon(LineIcons.trash, color: Colors.red[300], size: 20),
                             onPressed: () => confirmDelete(sucursal['id']),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _filteredSucursales.length,
      ),
    );
  }
}

class SucursalForm extends StatefulWidget {
  final Map<String, dynamic>? sucursal;
  final VoidCallback onSuccess;

  const SucursalForm({Key? key, this.sucursal, required this.onSuccess}) : super(key: key);

  @override
  _SucursalFormState createState() => _SucursalFormState();
}

class _SucursalFormState extends State<SucursalForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController hwidController = TextEditingController();
  bool estado = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.sucursal != null) {
      nombreController.text = widget.sucursal!['nombre'];
      direccionController.text = widget.sucursal!['direccion'] ?? "";
      hwidController.text = widget.sucursal!['hwid'] ?? "";
      estado = widget.sucursal!['estado'] == 'activa';
    }
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    final body = {
      "nombre": nombreController.text,
      "direccion": direccionController.text,
      "hwid": hwidController.text,
      "estado": estado ? "activa" : "inactiva",
    };
    
    try {
      if (widget.sucursal == null) {
        await ApiService().dio.post(getApiUrl("sucursales"), data: body);
        showTopNotification("Éxito", "Sucursal creada correctamente", true);
      } else {
        await ApiService().dio.put(getApiUrl("sucursales/${widget.sucursal!['id']}"), data: body);
        showTopNotification("Éxito", "Sucursal actualizada correctamente", true);
      }
      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      showTopNotification("Error", "Error al guardar la sucursal", false);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showTopNotification(String title, String message, bool success) {
    final snackBar = success
        ? CustomSnackBar.success(message: "$title\n$message")
        : CustomSnackBar.error(message: "$title\n$message");
    showTopSnackBar(Overlay.of(context)!, snackBar, displayDuration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título del formulario
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC026D3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.sucursal == null ? LineIcons.plus : LineIcons.edit,
                      color: const Color(0xFFC026D3),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.sucursal == null ? "Crear Sucursal" : "Editar Sucursal",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Nombre de la sucursal
              TextFormField(
                controller: nombreController,
                style: GoogleFonts.poppins(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Nombre de la sucursal",
                  hintText: "Ej: Sucursal Central",
                  labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: const Icon(LineIcons.building, color: Color(0xFFC026D3)),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC026D3), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.red.shade200),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.red.shade400),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                validator: (value) => value!.isEmpty ? "Ingrese el nombre" : null,
              ),
              
              const SizedBox(height: 20),
              
              // Dirección
              TextFormField(
                controller: direccionController,
                style: GoogleFonts.poppins(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Dirección de la sucursal",
                  hintText: "Ej: Av. Principal #123",
                  labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: const Icon(LineIcons.mapMarker, color: Color(0xFFC026D3)),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC026D3), width: 2),
                  ),
                   errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.red.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                ),
                validator: (value) => value!.isEmpty ? "Ingrese la dirección" : null,
              ),
              
              const SizedBox(height: 20),
              
              // HWID
              TextFormField(
                controller: hwidController,
                style: GoogleFonts.poppins(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "HWID (Identificador único)",
                  hintText: "Código único de hardware",
                   labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: const Icon(LineIcons.qrcode, color: Color(0xFFC026D3)),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC026D3), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Estado
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  title: Text(
                    "Estado: ${estado ? 'Activa' : 'Inactiva'}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  value: estado,
                  onChanged: (value) => setState(() => estado = value),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  activeTrackColor: Colors.green.withOpacity(0.3),
                  inactiveTrackColor: Colors.red.withOpacity(0.3),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: estado ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      estado ? LineIcons.checkCircle : LineIcons.timesCircle,
                      color: estado ? Colors.green : Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Cancelar",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC026D3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: const Color(0xFFC026D3).withOpacity(0.4),
                      ),
                      child: isLoading 
                        ? const SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                          )
                        : Text(
                            "Guardar Cambios",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
