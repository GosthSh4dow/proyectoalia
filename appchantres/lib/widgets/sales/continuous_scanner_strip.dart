import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Tira mini-escáner siempre visible (lector de supermercado).
///
/// El [controller] vive en la pantalla (para pausar en checkout/dispose).
/// No hace `setState` del padre: el flash usa [flashOk] local.
class ContinuousScannerStrip extends StatefulWidget {
  const ContinuousScannerStrip({
    super.key,
    required this.controller,
    required this.onCodigoDetectado,
    required this.flashOk,
    this.onPermisoDenegado,
  });

  final MobileScannerController controller;
  final ValueChanged<String> onCodigoDetectado;
  final ValueNotifier<bool> flashOk;
  final VoidCallback? onPermisoDenegado;

  @override
  State<ContinuousScannerStrip> createState() =>
      _ContinuousScannerStripState();
}

class _ContinuousScannerStripState extends State<ContinuousScannerStrip> {
  bool _permisoDenegado = false;
  bool _torchOn = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5D0FE)),
      ),
      child: Row(
        children: [
          // Viewfinder 72x72
          ValueListenableBuilder<bool>(
            valueListenable: widget.flashOk,
            builder: (_, ok, __) => Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ok
                      ? const Color(0xFF047857)
                      : const Color(0xFFC026D3),
                  width: ok ? 3 : 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_permisoDenegado)
                      MobileScanner(
                        controller: widget.controller,
                        onDetect: (capture) {
                          final code =
                              capture.barcodes.firstOrNull?.rawValue;
                          if (code != null && code.isNotEmpty) {
                            widget.onCodigoDetectado(code);
                          }
                        },
                        errorBuilder: (_, error) {
                          if (error.errorCode ==
                              MobileScannerErrorCode.permissionDenied) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => _permisoDenegado = true);
                                widget.onPermisoDenegado?.call();
                              }
                            });
                          }
                          return const SizedBox.shrink();
                        },
                      )
                    else
                      const Center(
                        child: Icon(LineIcons.barcode,
                            color: Colors.white54, size: 28),
                      ),
                    // Esquinas
                    ..._esquinas(),
                    if (ok)
                      const Center(
                        child: Icon(Icons.check_circle,
                            color: Color(0xFF34D399), size: 30),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Escanear producto',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B0764),
                  ),
                ),
                Text(
                  'Apunta al código o escribe',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          // Linterna 48dp (estado local: mobile_scanner 7.1 no expone torchState)
          SizedBox(
            width: 48.w,
            height: 48.w,
            child: IconButton(
              onPressed: () async {
                try {
                  await widget.controller.toggleTorch();
                } catch (_) {}
                if (mounted) setState(() => _torchOn = !_torchOn);
              },
              icon: Icon(
                _torchOn ? LineIcons.lightbulb : LineIcons.lightbulbAlt,
                color: _torchOn
                    ? const Color(0xFFB45309)
                    : const Color(0xFF4B5563),
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    _torchOn ? const Color(0xFFFFFBEB) : Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _esquinas() {
    const c = Color(0xFFC026D3);
    const s = 16.0;
    const w = 3.0;
    Widget e({required bool l, required bool t}) => Positioned(
          left: l ? 4 : null,
          right: l ? null : 4,
          top: t ? 4 : null,
          bottom: t ? null : 4,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              border: Border(
                left: l
                    ? const BorderSide(color: c, width: w)
                    : BorderSide.none,
                right: l
                    ? BorderSide.none
                    : const BorderSide(color: c, width: w),
                top: t
                    ? const BorderSide(color: c, width: w)
                    : BorderSide.none,
                bottom: t
                    ? BorderSide.none
                    : const BorderSide(color: c, width: w),
              ),
            ),
          ),
        );
    return [e(l: true, t: true), e(l: false, t: true), e(l: true, t: false), e(l: false, t: false)];
  }
}
