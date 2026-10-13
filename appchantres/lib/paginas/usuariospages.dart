import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:ui';
import '../api.dart';
import '../servicios/api_service.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({Key? key}) : super(key: key);

  @override
  _UsuariosPageState createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> with SingleTickerProviderStateMixin {
  List<dynamic> usuarios = [];
  List<dynamic> sucursales = [];
  List<dynamic> _filteredUsuarios = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  
  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Colores corporativos (Purple Theme)
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
    
    fetchUsuarios();
    fetchSucursales();
    _searchController.addListener(_filterUsuarios);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterUsuarios);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _filterUsuarios() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredUsuarios = List.from(usuarios);
      } else {
        _filteredUsuarios = usuarios.where((usuario) {
          final nombre = usuario['nombre'].toString().toLowerCase();
          final email = usuario['email'].toString().toLowerCase();
          final rol = usuario['rol'].toString().toLowerCase();
          return nombre.contains(query) || email.contains(query) || rol.contains(query);
        }).toList();
      }
    });
  }

  Future<void> fetchUsuarios() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService().dio.get(getApiUrl("usuarios"));
      if (response.statusCode == 200) {
        setState(() {
          usuarios = response.data;
          _filteredUsuarios = List.from(usuarios);
        });
      } else {
        showTopNotification("Error", "Error al cargar los usuarios", false);
      }
    } catch (e) {
      showTopNotification("Error", "Error de conexión", false);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchSucursales() async {
    try {
      final response = await ApiService().dio.get(getApiUrl("sucursales"));
      if (response.statusCode == 200) {
        setState(() => sucursales = response.data);
      }
    } catch (e) {
      showTopNotification("Error", "No se pudieron cargar las sucursales", false);
    }
  }

  void showTopNotification(String title, String message, bool success) {
    final snackBar = success
        ? CustomSnackBar.success(message: "$title\n$message")
        : CustomSnackBar.error(message: "$title\n$message");
    showTopSnackBar(Overlay.of(context)!, snackBar, displayDuration: const Duration(seconds: 2));
  }

  void showFormModal({Map<String, dynamic>? usuario}) {
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
                child: UsuarioForm(
                  usuario: usuario,
                  sucursales: sucursales,
                  onSuccess: fetchUsuarios,
                ).animate().fadeIn(duration: const Duration(milliseconds: 300)).slideY(begin: 0.2),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "¿Eliminar usuario?",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
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
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await deleteUsuario(id);
              },
              child: Text(
                "Eliminar", 
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteUsuario(int id) async {
    try {
      setState(() => isLoading = true);
      final response = await ApiService().dio.delete(getApiUrl("usuarios/$id"));
      if (response.statusCode == 200) {
        fetchUsuarios();
        showTopNotification("Éxito", "Usuario eliminado correctamente", true);
      } else {
        showTopNotification("Error", "Error al eliminar el usuario", false);
      }
    } catch (e) {
      showTopNotification("Error", "Error de conexión", false);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> cambiarEstadoUsuario(Map<String, dynamic> usuario, String nuevoEstado) async {
    try {
      setState(() => isLoading = true);
      await ApiService().dio.put(
        getApiUrl("usuarios/${usuario['id']}"), 
        data: {"estado": nuevoEstado}
      );
      fetchUsuarios();
      showTopNotification("Éxito", "Estado actualizado", true);
    } catch (e) {
      showTopNotification("Error", "Error al cambiar estado", false);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
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
              : _filteredUsuarios.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : _buildUsuariosList(),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 80)),
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
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
        onPressed: () => Scaffold.of(context).openDrawer(),
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
                      'Usuarios',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Gestión de personal',
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
          hintText: 'Buscar usuario...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          prefixIcon: Icon(LineIcons.search, color: primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    int total = _filteredUsuarios.length;
    int admins = _filteredUsuarios.where((u) => u['rol'] == 'administrador').length;
    int activos = _filteredUsuarios.where((u) => u['estado'] == 'activado').length;

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
          _buildStatisticItem('$total', 'Total', LineIcons.users),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          _buildStatisticItem('$admins', 'Admins', LineIcons.userShield),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          _buildStatisticItem('$activos', 'Activos', LineIcons.checkCircle),
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
            LineIcons.user, 
            size: 100,
            color: Colors.grey[300],
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2000.ms)
           .moveY(begin: 0, end: -10, duration: 2000.ms),
           
          const SizedBox(height: 24),
          Text(
            'No hay usuarios encontrados',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn().slideY(begin: 0.5, duration: 500.ms),
          
          const SizedBox(height: 8),
          Text(
            'Intenta ajustar tu búsqueda o crea uno nuevo.',
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

  Widget _buildUsuariosList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final usuario = _filteredUsuarios[index];
          final bool isAdmin = usuario['rol'] == 'administrador';
          final bool isActive = usuario['estado'] == 'activado';
          
          return Animate(
            effects: [
              FadeEffect(delay: Duration(milliseconds: 50 * index), duration: 300.ms),
              SlideEffect(begin: const Offset(0.05, 0), end: const Offset(0, 0), delay: Duration(milliseconds: 50 * index), duration: 300.ms),
            ],
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isAdmin ? primaryColor.withOpacity(0.3) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    tilePadding: const EdgeInsets.all(16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAdmin 
                          ? primaryColor.withOpacity(0.1) 
                          : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isAdmin ? LineIcons.userShield : LineIcons.user,
                        color: isAdmin ? primaryColor : Colors.blue,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      usuario['nombre'] ?? 'Sin nombre',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          usuario['email'] ?? 'Sin email',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildTag(
                              isAdmin ? 'ADMIN' : 'USUARIO',
                              isAdmin ? primaryColor : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                             _buildTag(
                              isActive ? 'ACTIVO' : 'INACTIVO',
                              isActive ? Colors.green : Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Container(height: 1, color: Colors.grey[100]),
                            const SizedBox(height: 16),
                            _buildDetailRow("Sucursal", usuario['sucursal']?['nombre'] ?? 'Sin asignar', LineIcons.building),
                            _buildDetailRow("Turno", usuario['turno'] ?? 'No especificado', LineIcons.clock),
                            _buildDetailRow(
                              "Horario", 
                              "${usuario['hora_entrada']?.substring(0, 5) ?? '00:00'} - ${usuario['hora_salida']?.substring(0, 5) ?? '00:00'}", 
                              LineIcons.calendar
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Switch(
                                  value: isActive,
                                  activeColor: Colors.green,
                                  onChanged: (val) => cambiarEstadoUsuario(usuario, val ? 'activado' : 'inactivo'),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(LineIcons.edit, color: primaryColor),
                                  onPressed: () => showFormModal(usuario: usuario),
                                ),
                                IconButton(
                                  icon: Icon(LineIcons.trash, color: Colors.red[300]),
                                  onPressed: () => confirmDelete(usuario['id']),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _filteredUsuarios.length,
      ),
    );
  }
  
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text(
            "$label:",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.grey[800],
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class UsuarioForm extends StatefulWidget {
  final Map<String, dynamic>? usuario;
  final List<dynamic> sucursales;
  final VoidCallback onSuccess;

  const UsuarioForm({
    Key? key, 
    this.usuario, 
    required this.sucursales, 
    required this.onSuccess
  }) : super(key: key);

  @override
  _UsuarioFormState createState() => _UsuarioFormState();
}

class _UsuarioFormState extends State<UsuarioForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  String? rolSeleccionado;
  dynamic sucursalSeleccionada;
  String? turnoSeleccionado;
  bool estado = true;
  bool isLoading = false;
  
  final Color primaryColor = const Color(0xFFC026D3);

  // Datos para time pickers
  TimeOfDay horaEntrada = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay horaSalida = const TimeOfDay(hour: 17, minute: 0);
  
  final List<String> turnos = ['Mañana', 'Tarde', 'Noche', 'Completo'];

  @override
  void initState() {
    super.initState();
    if (widget.usuario != null) {
      // Cargar datos del usuario para edición
      nombreController.text = widget.usuario!['nombre'] ?? '';
      emailController.text = widget.usuario!['email'] ?? '';
      rolSeleccionado = widget.usuario!['rol'];
      
      // Buscar la sucursal correspondiente
      if (widget.usuario!['id_sucursal'] != null) {
        for (var sucursal in widget.sucursales) {
          if (sucursal['id'] == widget.usuario!['id_sucursal']) {
            sucursalSeleccionada = sucursal;
            break;
          }
        }
      }
      
      // Parse hora entrada
      if (widget.usuario!['hora_entrada'] != null) {
        final parts = widget.usuario!['hora_entrada'].split(':');
        if (parts.length >= 2) {
          horaEntrada = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8, 
            minute: int.tryParse(parts[1]) ?? 0
          );
        }
      }
      
      // Parse hora salida
      if (widget.usuario!['hora_salida'] != null) {
        final parts = widget.usuario!['hora_salida'].split(':');
        if (parts.length >= 2) {
          horaSalida = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 17, 
            minute: int.tryParse(parts[1]) ?? 0
          );
        }
      }
      
      turnoSeleccionado = widget.usuario!['turno'] ?? 'Mañana';
      estado = widget.usuario!['estado'] == 'activado';
    } else {
      // Valores por defecto para nuevo usuario
      rolSeleccionado = 'usuario';
      turnoSeleccionado = 'Mañana';
      estado = true;
    }
  }
  
  String formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    final Map<String, dynamic> data = {
      "nombre": nombreController.text,
      "email": emailController.text,
      "rol": rolSeleccionado,
      "id_sucursal": sucursalSeleccionada?['id'],
      "hora_entrada": formatTimeOfDay(horaEntrada),
      "hora_salida": formatTimeOfDay(horaSalida),
      "turno": turnoSeleccionado,
      "estado": estado ? "activado" : "inactivo",
    };
    
    // Solo incluir password si está presente y es edición o es un nuevo usuario
    if (passwordController.text.isNotEmpty) {
      data["password"] = passwordController.text;
    }
    
    try {
      if (widget.usuario == null) {
        // Crear nuevo usuario
        await ApiService().dio.post(getApiUrl("usuarios"), data: data);
        showTopNotification("Éxito", "Usuario creado correctamente", true);
      } else {
        // Actualizar usuario existente
        await ApiService().dio.put(getApiUrl("usuarios/${widget.usuario!['id']}"), data: data);
        showTopNotification("Éxito", "Usuario actualizado correctamente", true);
      }
      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      showTopNotification("Error", "Error al guardar el usuario", false);
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
            children: [
              // Título del formulario
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.usuario == null ? LineIcons.userPlus : LineIcons.userEdit,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.usuario == null ? "Crear Usuario" : "Editar Usuario",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Campos del formulario
              _buildModernTextField(
                controller: nombreController,
                label: "Nombre completo",
                hint: "Ej: Juan Pérez",
                icon: LineIcons.user,
                validator: (value) => value!.isEmpty ? "Ingrese el nombre" : null,
              ),
              
              const SizedBox(height: 20),
              
              _buildModernTextField(
                controller: emailController,
                label: "Correo electrónico",
                hint: "usuario@ejemplo.com",
                icon: LineIcons.envelope,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return "Ingrese el correo electrónico";
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(value)) return "Correo electrónico inválido";
                  return null;
                },
              ),
              
              const SizedBox(height: 20),

              _buildModernTextField(
                controller: passwordController,
                label: widget.usuario == null ? "Contraseña" : "Nueva contraseña (opcional)",
                hint: "********",
                icon: LineIcons.lock,
                isPassword: true,
                validator: (value) {
                  if (widget.usuario == null && value!.isEmpty) {
                     return "Ingrese una contraseña";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),
              
              // Dropdowns styled similar to inputs
              Row(
                children: [
                  Expanded(
                    child: _buildModernDropdown(
                      value: rolSeleccionado,
                      label: "Rol",
                      icon: LineIcons.userShield,
                      items: [
                        const DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
                        const DropdownMenuItem(value: 'usuario', child: Text('Usuario')),
                      ],
                      onChanged: (val) => setState(() => rolSeleccionado = val as String?),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernDropdown(
                      value: turnoSeleccionado,
                      label: "Turno",
                      icon: LineIcons.clock,
                      items: turnos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => turnoSeleccionado = val as String?),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Sucursal Dropdown
              _buildModernDropdown(
                value: sucursalSeleccionada,
                label: "Sucursal asignada",
                icon: LineIcons.building,
                items: widget.sucursales.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s['nombre']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => sucursalSeleccionada = val),
                hint: "Seleccione una sucursal",
              ),
              
              const SizedBox(height: 20),
              
              // Time Pickers Row
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(
                      "Entrada", 
                      horaEntrada, 
                      (picked) => setState(() => horaEntrada = picked),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePicker(
                      "Salida", 
                      horaSalida, 
                      (picked) => setState(() => horaSalida = picked),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
               // Estado Switch
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  title: Text(
                    "Estado: ${estado ? 'Activo' : 'Inactivo'}",
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
              
              // Buttons
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
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              "Guardar",
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
  
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
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
      validator: validator,
    );
  }

  Widget _buildModernDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? hint,
  }) {
    return DropdownButtonFormField2(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
      ),
      items: items,
      onChanged: onChanged,
      hint: hint != null ? Text(hint, style: GoogleFonts.poppins(color: Colors.grey[400])) : null,
      dropdownStyleData: DropdownStyleData(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      iconStyleData: IconStyleData(
        icon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LineIcons.clock, size: 20, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
