import 'package:intl/intl.dart';

class ReceiptBuilder {
  static const int LINE_WIDTH = 48;
  static final String SEPARATOR = "-" * LINE_WIDTH;

  static String _centerText(String text) {
    if (text.length >= LINE_WIDTH) return text;
    final spaces = ((LINE_WIDTH - text.length) / 2).floor();
    return " " * spaces + text;
  }

  static String buildEpsonReceipt({
    required Map<String, dynamic> ventaInfo,
    required List<dynamic> detalles,
    Map<String, dynamic>? cliente,
    bool noReceipt = false,
    num montoEntregado = 0.0,
    num cambio = 0.0,
  }) {
    String recibo = "";

    recibo += "\x1B\x40"; // Reset impresora
    recibo += _centerText("BISUTERIA Y ACCESORIOS") + "\n";
    recibo += _centerText("CHANNEL'S") + "\n";

    if (ventaInfo['sucursal_nombre'] != null &&
        ventaInfo['sucursal_nombre'].toString().trim().isNotEmpty &&
        ventaInfo['sucursal_nombre'].toString() != 'Sin Sucursal') {
      recibo += _centerText(ventaInfo['sucursal_nombre']) + "\n";
    }

    if (ventaInfo['sucursal_direccion'] != null &&
        ventaInfo['sucursal_direccion'].toString().trim().isNotEmpty &&
        ventaInfo['sucursal_direccion'].toString() != "Sin Dirección") {
      recibo += _centerText(ventaInfo['sucursal_direccion']) + "\n";
    }

    if (ventaInfo['sucursal_telefono'] != null &&
        ventaInfo['sucursal_telefono'].toString().trim().isNotEmpty) {
      recibo += _centerText("Contacto: ${ventaInfo['sucursal_telefono']}") + "\n";
    }

    final fecha = ventaInfo['fecha'] != null
        ? DateTime.parse(ventaInfo['fecha']).toLocal()
        : DateTime.now();
    recibo += "\x0E";
    recibo += _centerText(DateFormat('dd/MM/yyyy HH:mm').format(fecha)) + "\n";
    recibo += "\x0F";

    recibo += SEPARATOR + "\n";

    if (!noReceipt && cliente != null) {
      recibo += "Cliente: ${cliente['nombre_completo']}\n";
    }

    if (ventaInfo['usuario_nombre'] != null &&
        ventaInfo['usuario_nombre'].toString().trim().isNotEmpty) {
      recibo += "Vendedor: ${ventaInfo['usuario_nombre']}\n";
    }

    recibo += SEPARATOR + "\n";

    for (var detalle in detalles) {
      recibo += _buildDetalleCompacto(detalle);
    }

    recibo += SEPARATOR + "\n";
    recibo += "\x0E";
    recibo += _buildTotalsCompacto(ventaInfo, montoEntregado, cambio);
    recibo += "\x0F";
    recibo += SEPARATOR + "\n";
    recibo += _centerText("GRACIAS POR SU COMPRA") + "\n";
    recibo += _centerText("Esperamos verle pronto") + "\n";
    // El corte de papel ahora lo hace el servidor Node.js
    // recibo += "\x1D\x56\x41\x10"; // Cortar papel
    return recibo;
  }

  static String _buildDetalleCompacto(Map<String, dynamic> detalle) {
    String prodName = "";
    if (detalle["producto"] != null && detalle["producto"]["nombre"] != null) {
      prodName = detalle["producto"]["nombre"];
    }

    int cantidad = _parseIntValue(detalle["cantidad"]);
    double subtotal = _parseDoubleValue(detalle["subtotal"]);

    String cantidadStr = cantidad.toString();
    String subtotalStr = NumberFormat("0.00").format(subtotal);

    const int maxProductLength = 18;
    if (prodName.length > maxProductLength) {
      prodName = prodName.substring(0, maxProductLength);
    }

    String result = prodName.padRight(18) + " x$cantidadStr ";
    result = result.padRight(26) + subtotalStr.padLeft(7);
    result = result + " Bs\n";

    return result;
  }

  static String _buildTotalsCompacto(
      Map<String, dynamic> ventaInfo, num montoEntregado, num cambio) {
    double montoTotal = _parseDoubleValue(ventaInfo['monto_total']);
    double gemas = _parseDoubleValue(ventaInfo['gemas']);
    double descuentoPersonal = _parseDoubleValue(ventaInfo['descuento_personal']);
    
    // El frontend enviaba 'monto_total' como la sumatoria de productos
    // El backend lo guarda así. Calculamos el totalA Pagar restando
    double totalAPagar = montoTotal - gemas - descuentoPersonal;
    if (totalAPagar < 0) totalAPagar = 0;

    double montoEnt = montoEntregado is num ? montoEntregado.toDouble() : 0.0;
    double cambioVal = cambio is num ? cambio.toDouble() : 0.0;

    String result = "";
    
    if (gemas > 0 || descuentoPersonal > 0) {
      result += "Subtotal: Bs. " + NumberFormat("0.00").format(montoTotal) + "\n";
    }

    if (descuentoPersonal > 0) {
      if (ventaInfo['nombre_personal'] != null) {
        // Formateamos como "Desc. Nombre: -Bs. 0.00"
        String nombre = ventaInfo['nombre_personal'].toString();
        // Cortar el nombre si es muy largo para evitar que se desborde la línea
        if (nombre.length > 15) nombre = nombre.substring(0, 15);
        result += "Desc. $nombre: -Bs. " + NumberFormat("0.00").format(descuentoPersonal) + "\n";
      } else {
        result += "Desc. Personal: -Bs. " + NumberFormat("0.00").format(descuentoPersonal) + "\n";
      }
    }

    if (gemas > 0) {
      result += "Gemas Usadas: -Bs. " + NumberFormat("0.00").format(gemas) + "\n";
    }

    result += "Total a Pagar: Bs. " + NumberFormat("0.00").format(totalAPagar) + "\n";

    if (montoEnt > 0) {
      result +=
          "Entregado: Bs. " + NumberFormat("0.00").format(montoEnt) + "\n";
    }

    if (cambioVal > 0) {
      result += "Cambio: Bs. " + NumberFormat("0.00").format(cambioVal) + "\n";
    }

    return result;
  }

  /// Builds a plain-text receipt (no ESC/POS codes) suitable for sharing
  static String buildTextReceipt({
    required Map<String, dynamic> ventaInfo,
    required List<dynamic> detalles,
    Map<String, dynamic>? cliente,
    num montoEntregado = 0.0,
    num cambio = 0.0,
  }) {
    String recibo = "";

    recibo += "${_centerText("Bisuteria y Accesorios Channel's")}\n";

    if (ventaInfo['sucursal_nombre'] != null &&
        ventaInfo['sucursal_nombre'].toString().trim().isNotEmpty &&
        ventaInfo['sucursal_nombre'].toString() != 'Sin Sucursal') {
      recibo += "${_centerText(ventaInfo['sucursal_nombre'])}\n";
    }
    if (ventaInfo['sucursal_direccion'] != null &&
        ventaInfo['sucursal_direccion'].toString().trim().isNotEmpty &&
        ventaInfo['sucursal_direccion'].toString() != 'Sin Dirección') {
      recibo += "${_centerText(ventaInfo['sucursal_direccion'])}\n";
    }

    if (ventaInfo['sucursal_telefono'] != null &&
        ventaInfo['sucursal_telefono'].toString().trim().isNotEmpty) {
      recibo += "${_centerText("Contacto: ${ventaInfo['sucursal_telefono']}")}\n";
    }

    recibo += "$SEPARATOR\n";

    final fecha = ventaInfo['fecha'] != null
        ? DateTime.parse(ventaInfo['fecha']).toLocal()
        : DateTime.now();
    recibo += "Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}\n";

    if (ventaInfo['usuario_nombre'] != null &&
        ventaInfo['usuario_nombre'].toString().trim().isNotEmpty) {
      recibo += "Vendedor: ${ventaInfo['usuario_nombre']}\n";
    }

    if (cliente != null) {
      recibo += "Cliente: ${cliente['nombre_completo']}\n";
    }

    recibo += "$SEPARATOR\n";
    recibo += "Detalle de productos:\n";

    for (var detalle in detalles) {
      String prodName = detalle["producto"]?["nombre"] ?? "Producto";
      int cantidad = _parseIntValue(detalle["cantidad"]);
      double subtotal = _parseDoubleValue(detalle["subtotal"]);

      recibo +=
          "$prodName x$cantidad: Bs. ${NumberFormat('0.00').format(subtotal)}\n";
    }

    recibo += "$SEPARATOR\n";
    double montoTotal = _parseDoubleValue(ventaInfo['monto_total']);
    double gemas = _parseDoubleValue(ventaInfo['gemas']);
    double descuentoPersonal = _parseDoubleValue(ventaInfo['descuento_personal']);
    
    double totalAPagar = montoTotal - gemas - descuentoPersonal;
    if (totalAPagar < 0) totalAPagar = 0;

    if (gemas > 0 || descuentoPersonal > 0) {
      recibo += "Subtotal: Bs. ${NumberFormat('0.00').format(montoTotal)}\n";
    }
    
    if (descuentoPersonal > 0) {
      if (ventaInfo['nombre_personal'] != null) {
        String nombre = ventaInfo['nombre_personal'].toString();
        if (nombre.length > 15) nombre = nombre.substring(0, 15);
        recibo += "Desc. $nombre: -Bs. ${NumberFormat('0.00').format(descuentoPersonal)}\n";
      } else {
        recibo += "Desc. Personal: -Bs. ${NumberFormat('0.00').format(descuentoPersonal)}\n";
      }
    }

    if (gemas > 0) {
      recibo += "Gemas Usadas: -Bs. ${NumberFormat('0.00').format(gemas)}\n";
    }
    
    recibo += "Total a Pagar: Bs. ${NumberFormat('0.00').format(totalAPagar)}\n";
    if (montoEntregado > 0) {
      recibo +=
          "Entregado: Bs. ${NumberFormat('0.00').format(montoEntregado)}\n";
    }
    if (cambio > 0) {
      recibo += "Cambio: Bs. ${NumberFormat('0.00').format(cambio)}\n";
    }
    recibo += "$SEPARATOR\n";
    recibo += "${_centerText('GRACIAS POR SU COMPRA')}\n";

    return recibo;
  }

  static String buildBarcodeLabel({
    required String codigo,
    required String nombre,
    required num precio,
  }) {
    String label = "";

    label += "\x1B\x40";
    label += "\n";

    label += "*" * 32 + "\n";
    label +=
        _centerText(codigo.length <= 20 ? codigo : codigo.substring(0, 20)) +
            "\n";
    label += "*" * 32 + "\n";
    label += "\n";

    const int maxNameLength = 32;
    String displayName = nombre;
    if (displayName.length > maxNameLength) {
      displayName = displayName.substring(0, maxNameLength - 2) + "..";
    }
    label += _centerText(displayName) + "\n";
    label += "\n";

    String priceStr = "Bs. ${NumberFormat('0.00').format(precio)}";
    label += _centerText(priceStr) + "\n";
    label += "\n";
    label += "*" * 32 + "\n";
    // El corte de papel lo hace el servidor Node.js (printer.cut())
    // label += "\x1D\x56\x41\x10";
    return label;
  }

  static int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  static double _parseDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}
