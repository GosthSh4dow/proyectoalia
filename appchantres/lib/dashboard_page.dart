import 'package:appchannels/paginas/ventas.dart';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';

import '/paginas/sucursalespage.dart'; 
import '/paginas/usuariospages.dart';  
import '/paginas/productos_screen.dart';
import '/paginas/cajas_screen.dart';
import '/paginas/reportes_screen.dart';
import '/paginas/sueldos_boletas_screen.dart';
import '/paginas/pedidos_screen.dart';
import '/paginas/marcar_asistencia_screen.dart';
import '/paginas/entrada_masiva_screen.dart';
import '/paginas/main_navigation.dart';

import '/paginas/catalogo_screen.dart';
import 'widgets/dashboard/dashboard_header.dart';
import 'widgets/dashboard/dashboard_module_card.dart';
import 'widgets/dashboard/modern_drawer.dart';

// Modern Color Palette
const Color kPrimaryColor = Color(0xFFC026D3);     // Fuchsia-600
const Color kSecondaryColor = Color(0xFFE879F9);   // Fuchsia-400
const Color kDarkPurple = Color(0xFF701A75);       // Fuchsia-900
const Color kBackgroundLight = Color(0xFFFDF4FF);  // Rose-50
const Color kBackgroundDark = Color(0xFF1F1F2E);   // Dark Slate

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _currentSection = "Ventas"; 
  
  @override
  void initState() {
    super.initState();
    _loadLastSection();
  }
  
  Future<void> _loadLastSection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSection = prefs.getString('lastSection') ?? "Ventas";
    });
  }
  
  Future<void> _saveLastSection(String section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSection', section);
  }

  void _onSectionSelected(String section) {
    setState(() {
      _currentSection = section;
      _saveLastSection(section);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? kBackgroundDark : kBackgroundLight;
    
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.user['nombre'] ?? 'Usuario';
    final userPhotoUrl = userProvider.user['foto_url'];
    final branchName = userProvider.branch != null ? userProvider.branch!['nombre'] : 'Sucursal Principal';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      drawer: ModernDrawer(
        currentSection: _currentSection,
        onSectionSelected: _onSectionSelected,
      ),
      body: Stack(
        children: [
          // Background blobs/gradient
          Positioned(
            top: -100,
            right: -100,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -50,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Header with Animation
                if (_currentSection != "Productos" && _currentSection != "Cajas" && _currentSection != "Ventas" && _currentSection != "Pedidos" && _currentSection != "Reportes" && _currentSection != "Sucursales" && _currentSection != "Usuarios" && _currentSection != "Sueldos y Boletas" && _currentSection != "Asistencia" && _currentSection != "Configuración Catálogo" && _currentSection != "Entrada Masiva")
                  Builder(
                    builder: (context) {
                      return DashboardHeader(
                        userName: userName,
                        userPhotoUrl: userPhotoUrl,
                        branchName: branchName,
                        onMenuPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                        onProfilePressed: () {
                          // Navigate to profile or show modal
                        },
                      ).animate().slideY(begin: -1, end: 0, duration: 600.ms, curve: Curves.easeOut);
                    }
                  ),

                // Content Area
                Expanded(
                  child: _buildContent(isDark)
                      .animate(key: ValueKey(_currentSection)) // Animate when section changes
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.05, end: 0, curve: Curves.easeOut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_currentSection) {
      case "Ventas":
        return VentasScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Asistencia":
        return MarcarAsistenciaScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Sucursales":
        return SucursalesPage();
      case "Productos":
        return MainNavigationScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Reportes":
        return ReportesScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Usuarios":
        return const UsuariosPage();
      case "Cajas":
        return CajasScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Sueldos y Boletas":
        return SueldosBoletasScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Pedidos":
        return PedidosScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Configuración Catálogo":
        return CatalogoScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case "Entrada Masiva":
        return EntradaMasivaScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
      default:
        return const VentasScreen();
    }
  }
}
