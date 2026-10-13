import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum UploadModalPhase { compressing, uploading, success, error }

class UploadProgressController {
  _UploadProgressModalState? _state;

  void update(double progress, {String? message}) {
    _state?.updateProgress(progress, message: message);
  }

  void setPhase(UploadModalPhase phase, {String? message}) {
    _state?.setPhase(phase, message: message);
  }

  void complete() {
    _state?.complete();
  }

  void error(String message) {
    _state?.showError(message);
  }

  /// Retorna true si el usuario puso retry, false si canceló.
  Future<bool> waitForResult() async {
    return _state?.waitForResult() ?? Future.value(false);
  }
}

/// Muestra un modal de progreso de subida con retry y cancel.
UploadProgressController showUploadProgressModal(BuildContext context, {CancelToken? cancelToken}) {
  final controller = UploadProgressController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UploadProgressModal(
      controller: controller,
      cancelToken: cancelToken,
    ),
  );

  return controller;
}

class _UploadProgressModal extends StatefulWidget {
  final UploadProgressController controller;
  final CancelToken? cancelToken;

  const _UploadProgressModal({required this.controller, this.cancelToken});

  @override
  State<_UploadProgressModal> createState() => _UploadProgressModalState();
}

class _UploadProgressModalState extends State<_UploadProgressModal> {
  double _progress = 0;
  String _message = "Preparando imagen...";
  bool _completed = false;
  bool _hasError = false;
  UploadModalPhase _phase = UploadModalPhase.compressing;
  int _retryCount = 0;
  final Completer<bool> _resultCompleter = Completer<bool>();

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

  Future<bool> waitForResult() => _resultCompleter.future;

  void updateProgress(double progress, {String? message}) {
    if (mounted && !_completed) {
      setState(() {
        _progress = progress.clamp(0.0, 1.0);
        if (message != null) _message = message;
      });
    }
  }

  void setPhase(UploadModalPhase phase, {String? message}) {
    if (mounted) {
      setState(() {
        _phase = phase;
        if (message != null) _message = message;
        if (phase == UploadModalPhase.uploading) _progress = 0;
      });
    }
  }

  void complete() {
    if (mounted && !_completed) {
      setState(() {
        _completed = true;
        _phase = UploadModalPhase.success;
        _progress = 1.0;
        _message = "¡Completado!";
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          if (!_resultCompleter.isCompleted) _resultCompleter.complete(true);
          Navigator.of(context).pop();
        }
      });
    }
  }

  void showError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _phase = UploadModalPhase.error;
        _message = message;
        _retryCount++;
      });
    }
  }

  IconData _getPhaseIcon() {
    switch (_phase) {
      case UploadModalPhase.compressing:
        return Icons.image_not_supported_outlined;
      case UploadModalPhase.uploading:
        return Icons.cloud_upload;
      case UploadModalPhase.success:
        return Icons.check_circle;
      case UploadModalPhase.error:
        return Icons.error_outline;
    }
  }

  Color _getPhaseColor() {
    switch (_phase) {
      case UploadModalPhase.compressing:
        return Colors.orange;
      case UploadModalPhase.uploading:
        return Colors.blue;
      case UploadModalPhase.success:
        return Colors.green;
      case UploadModalPhase.error:
        return Colors.red;
    }
  }

  String _getPhaseLabel() {
    switch (_phase) {
      case UploadModalPhase.compressing:
        return 'Comprimiendo';
      case UploadModalPhase.uploading:
        return 'Subiendo';
      case UploadModalPhase.success:
        return 'Completado';
      case UploadModalPhase.error:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_completed) {
          widget.cancelToken?.cancel();
          if (!_resultCompleter.isCompleted) _resultCompleter.complete(false);
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPhaseColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getPhaseLabel(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getPhaseColor(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _getPhaseIcon(),
                  key: ValueKey(_phase),
                  size: 48,
                  color: _getPhaseColor(),
                ),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                _message,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Progress bar (only during upload/compress)
              if (!_hasError && !_completed) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_getPhaseColor()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress > 0 ? "${(_progress * 100).toInt()}%" : "Conectando...",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],

              // Retry count indicator
              if (_retryCount > 0 && !_hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'Intento ${_retryCount + 1}/4',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
              ],

              // Error actions
              if (_hasError) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (!_resultCompleter.isCompleted) _resultCompleter.complete(false);
                        Navigator.of(context).pop();
                      },
                      child: Text("Cancelar", style: GoogleFonts.poppins(color: Colors.grey)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Return true to signal retry
                        if (!_resultCompleter.isCompleted) _resultCompleter.complete(true);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC026D3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text("Reintentar", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],

              // Cancel button during upload
              if (!_hasError && !_completed) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    widget.cancelToken?.cancel();
                    if (!_resultCompleter.isCompleted) _resultCompleter.complete(false);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "Cancelar",
                    style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
