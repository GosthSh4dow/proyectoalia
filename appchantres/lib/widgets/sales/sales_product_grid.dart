import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_spinkit/flutter_spinkit.dart'; // <-- Importar SpinKit
import '../../models/producto.dart'; // Para el modelo Producto
import 'sales_product_card.dart'; // La tarjeta de producto que ya creamos

const Color kPrimaryColor = Color(0xFFC026D3);     // Fuchsia-600

class SalesProductGrid extends StatefulWidget {
  final List<Producto> productosFiltrados;
  final List<Map<String, dynamic>> carrito;
  final Function(String) onProductTap; // Callback para buscarProducto
  final double Function(Producto) calcularPrecioFinalCallback;
  final bool Function(Producto) tiene2x1Callback;
  final bool isLoading; // Para mostrar indicador de carga general

  const SalesProductGrid({
    Key? key,
    required this.productosFiltrados,
    required this.carrito,
    required this.onProductTap,
    required this.calcularPrecioFinalCallback,
    required this.tiene2x1Callback,
    required this.isLoading,
  }) : super(key: key);

  @override
  _SalesProductGridState createState() => _SalesProductGridState();
}

class _SalesProductGridState extends State<SalesProductGrid> {
  int _currentPage = 1;
  final int _pageSize = 6; // Número de productos por página
  List<Producto> _productosPaginados = [];

  @override
  void initState() {
    super.initState();
    if (!widget.isLoading) {
      _updatePage();
    }
  }

  @override
  void didUpdateWidget(SalesProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productosFiltrados != oldWidget.productosFiltrados ||
        (oldWidget.isLoading && !widget.isLoading)) {
      _currentPage = 1; // Resetear a la primera página si los filtros cambian
      _updatePage();
    }
  }

  void _updatePage() {
    if (widget.productosFiltrados.isEmpty && _currentPage != 1) {
      _currentPage = 1;
    }
    final start = (_currentPage - 1) * _pageSize;
    final end = (_currentPage * _pageSize > widget.productosFiltrados.length)
        ? widget.productosFiltrados.length
        : _currentPage * _pageSize;
    
    if (mounted) {
      setState(() {
        if (start <= end && end <= widget.productosFiltrados.length) {
          _productosPaginados = widget.productosFiltrados.sublist(start, end);
        } else {
          _productosPaginados = [];
        }
      });
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (widget.productosFiltrados.length / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                      _updatePage();
                    });
                  }
                : null,
            child: const Text('Anterior'),
          ),
          const SizedBox(width: 16),
          Text('Página $_currentPage de $totalPages'),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                      _updatePage();
                    });
                  }
                : null,
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: SpinKitFadingCircle( // <-- Usar SpinKit para consistencia
          color: kPrimaryColor, // Usar color premium
          size: 50.0,
        ),
      );
    }
    if (widget.productosFiltrados.isEmpty) {
      return const Center(child: Text("No se encontraron productos."));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            key: ValueKey(_currentPage), // Ayuda a reconstruir el grid si la página cambia
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: math.max(
                  2, (MediaQuery.of(context).size.width / 150).floor()),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: _productosPaginados.length,
            itemBuilder: (context, index) {
              final producto = _productosPaginados[index];
              double precioFinal = widget.calcularPrecioFinalCallback(producto);
              bool descuentoActivo = precioFinal < producto.precioVenta;
              bool isLowStock = producto.stock < 5;
              final itemInCarrito = widget.carrito.firstWhere(
                (item) => item['id'] == producto.id,
                orElse: () => {},
              );
              int cantidad = itemInCarrito.isNotEmpty ? itemInCarrito['cantidad'] : 0;

              return SalesProductCard(
                key: ValueKey(producto.id), // <-- AÑADIR KEY AL PRODUCT CARD
                producto: producto,
                onTap: () => widget.onProductTap(producto.codigoBarras),
                precioFinal: precioFinal,
                es2x1: widget.tiene2x1Callback(producto),
                cantidadEnCarrito: cantidad,
              );
            },
          ),
        ),
        _buildPaginationControls(),
      ],
    );
  }
}
