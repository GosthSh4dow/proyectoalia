import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart'; // Nueva librería
import 'package:line_icons/line_icons.dart';

import 'productos_screen.dart';
import '../componentes/promociones_componente.dart';
import '../componentes/proveedores_componente.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const MainNavigationScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<dynamic> _productosData = [];

  void _onDataChanged(List<dynamic> productos) {
    setState(() {
      _productosData = productos;
    });
  }

  late final List<Widget> _screens = [
    ProductosScreen(
      onDataChanged: _onDataChanged,
      onMenuPressed: widget.onMenuPressed,
    ),
    PromocionesComponente(
      productos: _productosData,
      onDataChanged: () => setState(() {}),
    ),
    ProveedoresComponente(
      onDataChanged: () => setState(() {}),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(20),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, LineIcons.boxes, 'Productos'),
            _buildNavItem(1, LineIcons.tag, 'Promociones'),
            _buildNavItem(2, LineIcons.userTie, 'Proveedores'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFC026D3) : Colors.grey.shade400,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC026D3),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
