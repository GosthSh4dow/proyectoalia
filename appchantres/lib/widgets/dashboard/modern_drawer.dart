import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

// Modern Color Palette (Matches Dashboard)
const Color kPrimaryColor = Color(0xFFC026D3);     // Fuchsia-600
const Color kSecondaryColor = Color(0xFFE879F9);   // Fuchsia-400
const Color kDarkPurple = Color(0xFF701A75);       // Fuchsia-900

class ModernDrawer extends StatelessWidget {
  final String currentSection;
  final Function(String) onSectionSelected;

  const ModernDrawer({
    Key? key,
    required this.currentSection,
    required this.onSectionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.user['nombre'] ?? 'Usuario';
    final userRol = userProvider.user['rol'] ?? 'usuario';
    final userSucursal = userProvider.branch != null 
        ? userProvider.branch!['nombre'] 
        : 'Sin sucursal asignada';
    final userPhotoUrl = userProvider.user['foto_url'];
    final isAdmin = userRol.toLowerCase() == 'administrador';

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.78,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // 1. Custom Header with Logo Background
          _buildHeader(userName, userRol, userSucursal, userPhotoUrl),

          // 2. Menu Items Body
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                // Gradient similar to ProductosScreen but softer for menu background
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFFDF4FF)], 
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMenuHeader("PRINCIPAL"),
                    _buildMenuItem(context, LineIcons.userCheck, "Asistencia"),
                    _buildMenuItem(context, LineIcons.shoppingCart, "Ventas"),
                    _buildMenuItem(context, LineIcons.shoppingBag, "Pedidos"),
                    _buildMenuItem(context, LineIcons.box, "Entrada Masiva"),
                    _buildMenuItem(context, LineIcons.fileInvoice, "Reportes"),
                    _buildMenuItem(context, LineIcons.cashRegister, "Cajas"),
                    
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildMenuHeader("ADMINISTRACIÓN"),
                      _buildMenuItem(context, LineIcons.store, "Sucursales"),
                      _buildMenuItem(context, LineIcons.boxes, "Productos"),
                      _buildMenuItem(context, LineIcons.users, "Usuarios"),
                      _buildMenuItem(context, LineIcons.moneyBill, "Sueldos y Boletas"),
                      _buildMenuItem(context, LineIcons.cog, "Configuración Catálogo"),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Footer
          Container(
             color: const Color(0xFFFDF4FF),
             padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
             child: _buildLogoutButton(context, userProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String role, String branch, String? photoUrl) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kDarkPurple,
        image: DecorationImage(
          image: AssetImage('assets/images/logo.jpeg'),
          fit: BoxFit.cover,
          opacity: 0.4, // Dim image for text visibility
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
             begin: Alignment.bottomCenter,
             end: Alignment.topCenter,
             colors: [
               kDarkPurple.withOpacity(0.9),
               kDarkPurple.withOpacity(0.3),
             ]
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
             Row(
               children: [
                 Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)
                    ]
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Text(
                            _getInitials(name),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
                          )
                        : null,
                  ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         name,
                         style: GoogleFonts.poppins(
                           color: Colors.white,
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                           shadows: [Shadow(color: Colors.black45, blurRadius: 4)]
                         ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                       Text(
                         role.toUpperCase(),
                         style: GoogleFonts.poppins(
                           color: kSecondaryColor,
                           fontSize: 11,
                           fontWeight: FontWeight.w600,
                           letterSpacing: 0.5,
                         ),
                       ),
                     ],
                   ),
                 )
               ],
             ),
             const SizedBox(height: 16),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.15),
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: Colors.white.withOpacity(0.2))
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(LineIcons.mapMarker, color: Colors.white70, size: 14),
                   const SizedBox(width: 6),
                   Flexible(
                     child: Text(
                       branch,
                       style: GoogleFonts.poppins(
                         color: Colors.white,
                         fontSize: 12,
                       ),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildMenuHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kPrimaryColor.withOpacity(0.7), // Using theme color
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title) {
    final bool isSelected = currentSection == title;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(); // Close drawer FIRST
            onSectionSelected(title);
          },
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? kPrimaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4)
                )
              ] : null
            ),
            child: Row(
              children: [
                Icon(
                  icon, 
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14)
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, UserProvider userProvider) {
    return OutlinedButton.icon(
      onPressed: () => _showLogoutConfirmation(context, userProvider),
      icon: const Icon(LineIcons.alternateSignOut, size: 20),
      label: Text("Cerrar Sesión", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade400,
        side: BorderSide(color: Colors.red.shade100, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Colors.red.withOpacity(0.05)
      ),
    );
  }

  String _getInitials(String name) {
    final List<String> names = name.split(" ");
    if (names.isNotEmpty) {
      if (names.length >= 2) return "${names[0][0]}${names[1][0]}".toUpperCase();
      if (names[0].isNotEmpty) return names[0][0].toUpperCase();
    }
    return "U";
  }

  void _showLogoutConfirmation(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
             Icon(LineIcons.exclamationCircle, color: Colors.red, size: 28),
             const SizedBox(width: 12),
             Text('Cerrar Sesión', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro que deseas cerrar tu sesión actual?',
          style: GoogleFonts.poppins(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await userProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Salir', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
