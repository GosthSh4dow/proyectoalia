import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';

/// PANTALLA PARA ESCANEAR CÓDIGO DE BARRAS / QR
class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _codeDetected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Escanear Código',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC026D3), // Fuchsia
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_codeDetected) return;
              
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  setState(() {
                    _codeDetected = true;
                  });
                  
                  HapticFeedback.mediumImpact();
                  
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.of(context).pop(code);
                      }
                    });
                  }
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 280.w,
              height: 280.w,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFE879F9), // Fuchsia Light
                  width: 4.0,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                   // Corners accents
                   Positioned(
                     top: 0, left: 0,
                     child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)), borderRadius: BorderRadius.only(topLeft: Radius.circular(30))))
                   ),
                   Positioned(
                     top: 0, right: 0,
                     child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)), borderRadius: BorderRadius.only(topRight: Radius.circular(30))))
                   ),
                   Positioned(
                     bottom: 0, left: 0,
                     child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30))))
                   ),
                   Positioned(
                     bottom: 0, right: 0,
                     child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)), borderRadius: BorderRadius.only(bottomRight: Radius.circular(30))))
                   ),
                   Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LineIcons.barcode, color: Colors.white.withOpacity(0.8), size: 60.sp),
                        SizedBox(height: 10.h),
                        Container(
                          width: 200.w,
                          height: 2,
                          color: const Color(0xFFC026D3).withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Instruction
          Positioned(
            bottom: 120.h,
            left: 20.w,
            right: 20.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'Enfoca el código de barras dentro del recuadro',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          // Cancel button
          Positioned(
            bottom: 40.h,
            left: 0,
            right: 0,
            child: Center(
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                    ]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LineIcons.times, color: Color(0xFFC026D3), size: 18),
                      SizedBox(width: 8.w),
                      Text(
                        "CANCELAR",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC026D3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
