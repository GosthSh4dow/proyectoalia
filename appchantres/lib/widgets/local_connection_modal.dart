import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../providers/local_connection_provider.dart';
import '../providers/user_provider.dart';

class LocalConnectionModal extends StatefulWidget {
  const LocalConnectionModal({Key? key}) : super(key: key);

  @override
  _LocalConnectionModalState createState() => _LocalConnectionModalState();
}

class _LocalConnectionModalState extends State<LocalConnectionModal> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  bool _isConnecting = false;

  // New Theme Colors
  final Color _primaryColor = const Color(0xFFC026D3); // Fuchsia-600
  final Color _secondaryColor = const Color(0xFFE879F9); // Fuchsia-400
  final Color _successColor = const Color(0xFF10B981); // Emerald-500
  final Color _errorColor = const Color(0xFFEF4444); // Red-500

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final localProvider = context.read<LocalConnectionProvider>();
        _hostController.text = localProvider.localHost;
        _portController.text = localProvider.localPort.toString();
      }
    });
    _hostController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '5000');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24.w,
        right: 24.w,
        top: 12.h,
      ),
      child: SingleChildScrollView(
        child: Consumer2<LocalConnectionProvider, UserProvider>(
          builder: (context, localProvider, userProvider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                 // Drag Handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 24.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Servidor Local',
                      style: GoogleFonts.poppins(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                     Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: localProvider.isConnected ? _successColor.withOpacity(0.1) : _errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(localProvider.isConnected ? Icons.wifi : Icons.wifi_off, size: 14.sp, color: localProvider.isConnected ? _successColor : _errorColor),
                          SizedBox(width: 4.w),
                          Text(
                            localProvider.isConnected ? 'CONECTADO' : 'DESCONECTADO',
                            style: GoogleFonts.poppins(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: localProvider.isConnected ? _successColor : _errorColor
                            )
                          )
                        ],
                      ),
                     )
                  ],
                ),
                SizedBox(height: 24.h),
                
                // Info Card
                if (localProvider.isConnected)
                  _buildStatusCard(localProvider),

                SizedBox(height: 24.h),
                
                if (!localProvider.isConnected) ...[
                  _buildInputField(
                    label: 'Dirección IP/Host',
                    controller: _hostController,
                    icon: LineIcons.desktop,
                    hint: '192.168.1.100',
                  ),
                  SizedBox(height: 16.h),
                  _buildInputField(
                    label: 'Puerto',
                    controller: _portController,
                    icon: LineIcons.bullseye,
                    hint: '5000',
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 32.h),
                  _buildConnectButton(localProvider, userProvider),
                ] else ...[
                  _buildDisconnectButton(localProvider),
                ],
                SizedBox(height: 30.h),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(LocalConnectionProvider localProvider) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _successColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _successColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                 BoxShadow(
                   color: _successColor.withOpacity(0.1),
                   blurRadius: 8,
                   offset: Offset(0, 4)
                 )
              ]
            ),
            child: Icon(LineIcons.checkCircle, color: _successColor, size: 28),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conexión Establecida',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${localProvider.localHost}:${localProvider.localPort}',
                   style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
           style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
             color: Colors.grey.shade50,
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey.shade900),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              prefixIcon: icon != null ? Icon(icon, color: _primaryColor) : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton(
    LocalConnectionProvider localProvider,
    UserProvider userProvider,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isConnecting
            ? null
            : () => _handleConnect(localProvider, userProvider),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFC026D3), const Color(0xFFE879F9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
             borderRadius: BorderRadius.circular(16),
             boxShadow: [
               BoxShadow(
                 color: _primaryColor.withOpacity(0.3),
                 blurRadius: 16,
                 offset: Offset(0, 8)
               )
             ]
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isConnecting
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Conectar Servidor',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectButton(LocalConnectionProvider localProvider) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _errorColor,
          elevation: 0,
          side: BorderSide(color: _errorColor.withOpacity(0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => _handleDisconnect(localProvider),
        child: Text(
          'Desconectar',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handleConnect(
    LocalConnectionProvider localProvider,
    UserProvider userProvider,
  ) async {
    setState(() => _isConnecting = true);

    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final userName = userProvider.user['nombre'] ?? 'Usuario Desconocido';

    if (host.isEmpty || portStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      setState(() => _isConnecting = false);
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puerto inválido')),
      );
      setState(() => _isConnecting = false);
      return;
    }

    localProvider.setLocalHost(host);
    localProvider.setLocalPort(port);

    final success = await localProvider.connectToLocalServer(userName);

    setState(() => _isConnecting = false);

    if (success) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${localProvider.errorMessage}'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  void _handleDisconnect(LocalConnectionProvider localProvider) async {
    await localProvider.disconnect();
    if (mounted) {
      Navigator.pop(context, false);
    }
  }
}
