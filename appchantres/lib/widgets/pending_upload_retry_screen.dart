import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pending_upload.dart';
import '../servicios/pending_upload_service.dart';
import '../servicios/upload_notification_service.dart';

/// Pantalla de reintento de subida de producto.
/// Muestra el producto que falló y permite reintentar
/// usando la imagen comprimida ya guardada.
class PendingUploadRetryScreen extends StatefulWidget {
  final String? pendingId;
  final PendingUpload? upload;

  const PendingUploadRetryScreen({super.key, this.pendingId, this.upload});

  @override
  _PendingUploadRetryScreenState createState() => _PendingUploadRetryScreenState();
}

class _PendingUploadRetryScreenState extends State<PendingUploadRetryScreen> {
  PendingUpload? _upload;
  bool _loading = true;
  bool _retrying = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (widget.upload != null) {
      _upload = widget.upload;
      _loading = false;
    } else if (widget.pendingId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final upload = await PendingUploadService().get(widget.pendingId!);
    if (!mounted) return;
    setState(() {
      _upload = upload;
      _loading = false;
    });
  }

  Future<void> _retry() async {
    final upload = _upload;
    if (upload == null || _retrying) return;

    setState(() {
      _retrying = true;
      _status = null;
    });

    final notif = UploadNotificationService();
    await notif.showUploadingNotification(message: 'Reintentando...');

    final response = await PendingUploadService().enviar(
      upload,
      onProgress: (sent, total) {
        if (total > 0) {
          final percent = (sent / total * 100).toInt();
          notif.showUploadingNotification(
            progress: percent,
            message: 'Subiendo... $percent%',
          );
        }
      },
    );

    if (!mounted) return;

    if (response.errorMsg == null) {
      await PendingUploadService().remove(upload.id);
      await notif.showSuccessNotification(message: '¡${upload.nombre} guardado!');
      await notif.cancelAll();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${upload.nombre} se subió correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _retrying = false;
        _status = response.errorMsg;
      });
      await notif.showErrorNotification(
        message: response.errorMsg,
        productName: upload.nombre,
        retryPayload: 'retry:${upload.id}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        title: Text(
          'Subida pendiente',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _upload == null
              ? _buildEmpty()
              : _buildRetry(_upload!),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text('No hay subidas pendientes', style: GoogleFonts.poppins(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRetry(PendingUpload upload) {
    final hasImages = upload.imagenPaths.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (hasImages) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              image: DecorationImage(
                image: FileImage(File(upload.imagenPaths.first)),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                upload.nombre,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                upload.isEditing ? 'Editar producto' : 'Nuevo producto',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (hasImages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${upload.imagenPaths.length} imagen(es) lista(s) para subir',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.green.shade700),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_status != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'Error: $_status',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.red.shade800),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _retrying ? null : _retry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC026D3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _retrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, color: Colors.white),
          label: Text(
            _retrying ? 'Reintentando...' : 'Reintentar subida',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            await PendingUploadService().remove(upload.id);
            if (mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          label: Text(
            'Descartar subida',
            style: GoogleFonts.poppins(color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}
