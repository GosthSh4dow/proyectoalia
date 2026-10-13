import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  Future<void> generateLowStockReport(List<dynamic> products) async {
    // Create a new PDF document.
    final PdfDocument document = PdfDocument();
    
    // Add a page to the document
    final PdfPage page = document.pages.add();
    
    // Create a PDF grid class to add tables.
    final PdfGrid grid = PdfGrid();
    
    // Specify the grid column count.
    grid.columns.add(count: 4);
    
    // Add a grid header row.
    final PdfGridRow headerRow = grid.headers.add(1)[0];
    headerRow.cells[0].value = 'Producto';
    headerRow.cells[1].value = 'Código';
    headerRow.cells[2].value = 'Categoría';
    headerRow.cells[3].value = 'Stock';
    
    // Set header style
    headerRow.style.backgroundBrush = PdfSolidBrush(PdfColor(192, 38, 211)); // Fuchsia
    headerRow.style.textBrush = PdfBrushes.white;
    headerRow.style.font = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);

    // Add rows to the grid.
    for (var product in products) {
      final PdfGridRow row = grid.rows.add();
      row.cells[0].value = _sanitize(product['nombre'].toString());
      row.cells[1].value = _sanitize(product['codigo_barras']?.toString() ?? 'N/A');
      row.cells[2].value = _sanitize(product['categoria']?['nombre'] ?? 'Sin categoría');
      row.cells[3].value = product['stock'].toString();
      
      // Style for low stock
      int stock = int.parse(product['stock'].toString());
      if (stock <= 5) {
        row.cells[3].style.textBrush = PdfBrushes.red;
        row.cells[3].style.font = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
      }
    }
    
    // Set grid format
    grid.style.cellPadding = PdfPaddings(left: 5, right: 5, top: 5, bottom: 5);
    
    // Draw the header
    page.graphics.drawString(
      'Reporte de Stock Bajo',
      PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(0, 0, 500, 30)
    );
    
    page.graphics.drawString(
      'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      PdfStandardFont(PdfFontFamily.helvetica, 10),
      bounds: Rect.fromLTWH(0, 30, 500, 20)
    );

    // Draw the grid
    grid.draw(
      page: page,
      bounds: const Rect.fromLTWH(0, 60, 0, 0),
    );
    
    // Save the document.
    final List<int> bytes = await document.save();
    
    // Dispose the document.
    document.dispose();
    
    // Save the file and launch it.
    await _saveAndLaunchFile(bytes, 'reporte_stock_bajo.pdf');
  }
  
  String _sanitize(String? input) {
    if (input == null) return '';
    // Filter out characters not supported by standard PDF fonts (Keep Latin-1)
    // Code units > 255 (0xFF) are likely to cause issues with standard fonts
    return String.fromCharCodes(
      input.runes.where((rune) => rune <= 255)
    );
  }
  
  Future<void> _saveAndLaunchFile(List<int> bytes, String fileName) async {
    // Get external storage directory
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final file = File('$path/$fileName');
    
    // Write PDF data
    await file.writeAsBytes(bytes, flush: true);
    
    // Open the PDF
    await OpenFile.open('$path/$fileName');
  }
}

