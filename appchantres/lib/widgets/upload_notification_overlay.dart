import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum UploadNotificationPhase { compressing, uploading, success, error }

/// Controlador para gestionar la notificación de subida desde cualquier parte.
class UploadNotificationController {
  _UploadNotificationOverlayState? _state;
  OverlayEntry? _entry;

  void update(double progress, {String? message}) {
    _state?.updateProgress(progress, message: message);
  }

  void setPhase(UploadNotificationPhase phase, {String? message}) {
    _state?.setPhase(phase, message: message);
  }

  void complete({String? message}) {
    _state?.complete(message: message);
  }

  void error(String message) {
    _state?.showError(message);
  }

  void dismiss() {
    _state?.dismiss();
  }
}

/// Muestra una notificación persistente no bloqueante tipo WhatsApp.
/// Retorna un controller para actualizar el progreso.
/// La notificación se muestra como un overlay en la parte superior
/// y NO bloquea la interacción del usuario.
UploadNotificationController showUploadNotification(BuildContext context) {
  final controller = UploadNotificationController();
  final overlay = Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _UploadNotificationOverlay(
      controller: controller,
      onDismiss: () {
        entry.remove();
      },
    ),
  );

  controller._entry = entry;
  overlay.insert(entry);
  return controller;
}

class _UploadNotificationOverlay extends StatefulWidget {
  final UploadNotificationController controller;
  final VoidCallback onDismiss;

  const _UploadNotificationOverlay({
    required this.controller,
    required this.onDismiss,
  });

  @override
  State<_UploadNotificationOverlay> createState() =>
      _UploadNotificationOverlayState();
}

class _UploadNotificationOverlayState
    extends State<_UploadNotificationOverlay> {
  double _progress = 0;
  String _message = "Preparando imagen...";
  bool _completed = false;
  bool _hasError = false;
  UploadNotificationPhase _phase = UploadNotificationPhase.compressing;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void dispose() {
    widget.controller._state = null;
    super.dispose();
  }

  void updateProgress(double progress, {String? message}) {
    if (mounted && !_completed) {
      setState(() {
        _progress = progress.clamp(0.0, 1.0);
        if (message != null) _message = message;
      });
    }
  }

  void setPhase(UploadNotificationPhase phase, {String? message}) {
    if (mounted) {
      setState(() {
        _phase = phase;
        if (message != null) _message = message;
        if (phase == UploadNotificationPhase.uploading) _progress = 0;
      });
    }
  }

  void complete({String? message}) {
    if (mounted && !_completed) {
      setState(() {
        _completed = true;
        _phase = UploadNotificationPhase.success;
        _progress = 1.0;
        _message = message ?? "¡Producto guardado!";
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) dismiss();
      });
    }
  }

  void showError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _phase = UploadNotificationPhase.error;
        _message = message;
      });
    }
  }

  void dismiss() {
    widget.onDismiss();
  }

  IconData _getPhaseIcon() {
    switch (_phase) {
      case UploadNotificationPhase.compressing:
        return Icons.image_not_supported_outlined;
      case UploadNotificationPhase.uploading:
        return Icons.cloud_upload;
      case UploadNotificationPhase.success:
        return Icons.check_circle;
      case UploadNotificationPhase.error:
        return Icons.error_outline;
    }
  }

  Color _getPhaseColor() {
    switch (_phase) {
      case UploadNotificationPhase.compressing:
        return Colors.orange;
      case UploadNotificationPhase.uploading:
        return const Color(0xFF3B82F6);
      case UploadNotificationPhase.success:
        return const Color(0xFF22C55E);
      case UploadNotificationPhase.error:
        return const Color(0xFFEF4444);
    }
  }

  String _getPhaseLabel() {
    switch (_phase) {
      case UploadNotificationPhase.compressing:
        return 'Comprimiendo';
      case UploadNotificationPhase.uploading:
        return 'Subiendo';
      case UploadNotificationPhase.success:
        return 'Completado';
      case UploadNotificationPhase.error:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPhaseColor();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: _phase == UploadNotificationPhase.uploading ||
                              _phase == UploadNotificationPhase.compressing
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: color,
                                value: _progress > 0 ? _progress : null,
                              ),
                            )
                          : Icon(_getPhaseIcon(), color: color, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPhaseLabel(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _message,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Close / progress text
                    if (!_hasError && !_completed)
                      Text(
                        _progress > 0
                            ? "${(_progress * 100).toInt()}%"
                            : "...",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),

                    if (_hasError)
                      TextButton(
                        onPressed: dismiss,
                        child: Text("Cerrar",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey)),
                      ),

                    if (_completed)
                      Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                  ],
                ),

                // Progress bar (only during upload/compress)
                if (!_hasError && !_completed) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
