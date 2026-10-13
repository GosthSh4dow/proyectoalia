import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../api.dart';
import '../servicios/ai_service.dart';
import '../servicios/api_service.dart';
import '../providers/user_provider.dart';
import '../providers/audio_recording_provider.dart';
import '../widgets/scan_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final File? imageFile;
  final Map<String, dynamic>? productData;
  final AudioMessageData? audioData;
  final bool isLoading;
  final bool isError;
  final VoidCallback? onRetry;
  final bool isConfirmed;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageFile,
    this.productData,
    this.audioData,
    this.isLoading = false,
    this.isError = false,
    this.onRetry,
    this.isConfirmed = false,
  });
}

class AudioMessageData {
  final int durationSeconds;
  final int fileSizeBytes;
  final String formattedDuration;
  final String formattedSize;

  AudioMessageData({
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.formattedDuration,
    required this.formattedSize,
  });
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({Key? key}) : super(key: key);

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = ApiService().dio;

  String? _lastText;
  File? _lastImage;

  File? _pendingImage;
  String? _scannedBarcode;
  bool _isProcessing = false;
  String _selectedModel = 'glm-5.1';
  List<Map<String, String>> _availableModels = [];
  int _registeredCount = 0;
  List<Map<String, dynamic>> _pendingProducts = [];

  // Audio recording
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHoldingMic = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Hola! Soy tu asistente AI para registrar productos.\n\n'
          'Puedes escribir, adjuntar una foto, escanear un código de barras '
          'o mantener presionado el micrófono para describir el producto por voz.',
      isUser: false,
    ));
    _cargarModelos();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _cargarModelos() async {
    final modelos = await _aiService.obtenerModelos();
    if (modelos.isNotEmpty && mounted) {
      setState(() => _availableModels = modelos);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));
    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((x, y) => x < y ? x : y);
        }
      }
    }
    return dp[a.length][b.length];
  }

  bool _fuzzyMatch(String query, String candidate) {
    final q = query.toLowerCase().trim();
    final c = candidate.toLowerCase().trim();
    if (c.contains(q) || q.contains(c)) return true;
    final qTokens = q.split(RegExp(r'[\s,.-]+'));
    final cTokens = c.split(RegExp(r'[\s,.-]+'));
    for (final qt in qTokens) {
      if (qt.length < 3) continue;
      for (final ct in cTokens) {
        if (ct.length < 3) continue;
        final dist = _levenshtein(qt, ct);
        final maxDist = (qt.length / 4).floor().clamp(1, 3);
        if (dist <= maxDist) return true;
      }
    }
    return false;
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: 'Hola! Soy tu asistente AI para registrar productos.\n\n'
            'Puedes escribir, adjuntar una foto, escanear un código de barras '
            'o mantener presionado el micrófono para describir el producto por voz.',
        isUser: false,
      ));
      _pendingImage = null;
      _scannedBarcode = null;
      _pendingProducts = [];
      _registeredCount = 0;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===================== IMAGE & BARCODE =====================

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Añadir Imagen',
                style: GoogleFonts.poppins(
                    fontSize: 18.sp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(Icons.camera_alt, 'Cámara', Colors.pink, () {
                  Navigator.pop(context);
                  _takePhoto(ImageSource.camera);
                }),
                _photoOption(Icons.image, 'Galería', Colors.blue, () {
                  Navigator.pop(context);
                  _takePhoto(ImageSource.gallery);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoOption(IconData icon, String label, MaterialColor color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.shade50,
            ),
            child: Icon(icon, size: 32, color: color.shade500),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _takePhoto(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (photo != null) {
      setState(() => _pendingImage = File(photo.path));
    }
  }

  Future<void> _scanCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
    if (result != null && result.toString().isNotEmpty) {
      setState(() => _scannedBarcode = result.toString());
    }
  }

  // ===================== TEXT MESSAGE =====================

  Future<void> _sendMessage({String? retryText, File? retryImage}) async {
    final text = retryText ?? _textController.text.trim();
    final image = retryImage ?? _pendingImage;
    if (text.isEmpty && image == null) return;

    _lastText = text;
    _lastImage = image;

    setState(() {
      if (retryText == null) {
        _messages.add(ChatMessage(
          text: text,
          isUser: true,
          imageFile: image,
        ));
      }
      _messages.add(ChatMessage(
        text: 'Analizando producto...',
        isUser: false,
        isLoading: true,
      ));
      _isProcessing = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      var fullText = text;
      if (_scannedBarcode != null && retryText == null) {
        fullText += ' (codigo de barras: $_scannedBarcode)';
      }

      String? contextoAnterior;
      try {
        final lastProductMsg = _messages.reversed.firstWhere(
          (m) => m.productData != null,
        );
        contextoAnterior = jsonEncode(lastProductMsg.productData);
      } catch (_) {}

      final results = await _aiService.interpretarProducto(
        texto: fullText,
        modelo: _selectedModel,
        contexto: contextoAnterior,
      );

      setState(() {
        _messages.removeLast();
        for (var result in results) {
          result['_temp_image'] = (retryImage ?? _pendingImage)?.path;
          result['_temp_codigos'] = <String>[];
          if (_scannedBarcode != null) {
            result['_temp_codigos'].add(_scannedBarcode);
          }
          _pendingProducts.add(result);
          final camposFaltantes = result['campos_faltantes'] as List<dynamic>? ?? [];
          String msg;
          if (camposFaltantes.isNotEmpty) {
            msg = 'Faltan: ${camposFaltantes.join(", ")}';
          } else {
            msg = 'Datos completos';
          }
          _messages.add(ChatMessage(
            text: msg,
            isUser: false,
            productData: result,
          ));
        }
        if (results.length > 1) {
          _messages.add(ChatMessage(
            text: 'Se interpretaron ${results.length} productos. Revisa cada uno y confírmalos.',
            isUser: false,
          ));
        }
        _pendingImage = null;
        _scannedBarcode = null;
        _isProcessing = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          text: 'Red inestable o error de conexión. Por favor reintenta.',
          isUser: false,
          isError: true,
          onRetry: () => _sendMessage(
            retryText: _lastText,
            retryImage: _lastImage,
          ),
        ));
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  // ===================== AUDIO RECORDING =====================

  void _onMicTapDown(AudioRecordingProvider audioProv) {
    _isHoldingMic = true;
    audioProv.startRecording();
  }

  void _onMicTapUp(AudioRecordingProvider audioProv) {
    if (!_isHoldingMic) return;
    _isHoldingMic = false;
    audioProv.stopRecordingAndProcess().then((_) {
      _handleAudioResult(audioProv);
    });
  }

  void _onMicTapCancel(AudioRecordingProvider audioProv) {
    if (!_isHoldingMic) return;
    _isHoldingMic = false;
    audioProv.cancelRecording();
  }

  void _handleAudioResult(AudioRecordingProvider audioProv) {
    if (audioProv.hasData && audioProv.productData != null) {
      final data = audioProv.productData!;
      final camposFaltantes = data.camposFaltantes;
      String mensaje;
      if (camposFaltantes.isNotEmpty) {
        mensaje = 'Audio procesado. Faltan: ${camposFaltantes.join(", ")}\n\nToca "Editar" para ajustar los datos.';
      } else {
        mensaje = 'Audio procesado exitosamente!\n\nToca "Editar" para ajustar los datos antes de confirmar.';
      }

      setState(() {
        _messages.add(ChatMessage(
          text: '🎤 Audio grabado (${audioProv.formattedDuration})',
          isUser: true,
          audioData: AudioMessageData(
            durationSeconds: audioProv.recordingDuration,
            fileSizeBytes: 0,
            formattedDuration: audioProv.formattedDuration,
            formattedSize: '',
          ),
        ));
        _messages.add(ChatMessage(
          text: mensaje,
          isUser: false,
          productData: data.toJson(),
        ));
      });
      _scrollToBottom();
    }
  }

  // ===================== PRODUCT CONFIRM =====================

  Future<void> _confirmProduct(Map<String, dynamic> data, {int? messageIndex}) async {
    File? imageToUpload;
    final tempImagePath = data['_temp_image'] as String?;
    if (tempImagePath != null && tempImagePath.isNotEmpty) {
      final file = File(tempImagePath);
      if (await file.exists()) {
        imageToUpload = file;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.branchId ?? 1;

      var catNombre = data['categoria']?.toString() ?? '';
      if (catNombre.isEmpty) catNombre = 'General';

      var provNombre = data['proveedor']?.toString() ?? '';
      if (provNombre.isEmpty) provNombre = 'Akzana';

      int? categoriaId;
      int? proveedorId;

      try {
        final cats = await _dio.get('$BASE_URL/categorias');
        final catList = (cats.data as List).cast<Map<String, dynamic>>();
        final existingCat = catList.firstWhere(
          (c) => _fuzzyMatch(catNombre, c['nombre'] as String),
          orElse: () => <String, dynamic>{},
        );
        if (existingCat.isNotEmpty) {
          categoriaId = existingCat['id'] as int;
        } else {
          final newCat = await _dio.post('$BASE_URL/categorias', data: {'nombre': catNombre});
          categoriaId = newCat.data['id'] as int;
        }
      } catch (_) {
        categoriaId = 1;
      }

      try {
        final provs = await _dio.get('$BASE_URL/proveedores');
        final provList = (provs.data as List).cast<Map<String, dynamic>>();
        final existingProv = provList.firstWhere(
          (p) => _fuzzyMatch(provNombre, p['nombre'] as String),
          orElse: () => <String, dynamic>{},
        );
        if (existingProv.isNotEmpty) {
          proveedorId = existingProv['id'] as int;
        } else {
          final newProv = await _dio.post('$BASE_URL/proveedores', data: {'nombre': provNombre});
          proveedorId = newProv.data['id'] as int;
        }
      } catch (_) {
        proveedorId = 1;
      }

      final codigo = data['codigo_barras'] ??
          'PROD-${DateTime.now().millisecondsSinceEpoch}';

      List<String> colores = [];
      if (data['colores'] is List) {
        colores = List<String>.from(data['colores'] as List);
      }

      List<Map<String, dynamic>> finalDistribuciones = [];
      final rawDists = data['distribuciones'] is List
          ? (data['distribuciones'] as List)
              .where((d) => d['nombre_sucursal'] != null && d['nombre_sucursal'].toString().trim().isNotEmpty)
              .toList()
          : [];

      if (rawDists.isNotEmpty) {
        try {
          final sucs = await _dio.get('$BASE_URL/sucursales');
          final sucursalesList = (sucs.data as List).cast<Map<String, dynamic>>();

          final ordinales = {
            'primera': 0, 'primer': 0, '1ra': 0, '1era': 0, '1': 0, 'primera sucursal': 0,
            'segunda': 1, 'segundo': 1, '2da': 1, '2era': 1, '2': 1, 'segunda sucursal': 1,
            'tercera': 2, 'tercer': 2, '3ra': 2, '3era': 2, '3': 2, 'tercera sucursal': 2,
            'cuarta': 3, 'cuarto': 3, '4ta': 3, '4': 3, 'cuarta sucursal': 3,
            'quinta': 4, '5ta': 4, '5': 4,
            'first': 0, 'second': 1, 'third': 2, 'fourth': 3,
            'principal': 0, 'central': 0, 'main': 0,
          };

          for (var dist in rawDists) {
            final nombreSuc = dist['nombre_sucursal'].toString().toLowerCase().trim();
            final cantidad = dist['cantidad'] ?? 1;
            int idSuc = branchId;

            final ordinalIdx = ordinales[nombreSuc];
            if (ordinalIdx != null && ordinalIdx < sucursalesList.length) {
              idSuc = sucursalesList[ordinalIdx]['id'] as int;
            } else {
              final existingSuc = sucursalesList.firstWhere(
                (s) {
                  final n = (s['nombre'] as String).toLowerCase();
                  return n.contains(nombreSuc) || nombreSuc.contains(n);
                },
                orElse: () => <String, dynamic>{},
              );
              if (existingSuc.isNotEmpty) {
                idSuc = existingSuc['id'] as int;
              }
            }

            finalDistribuciones.add({
              'id_sucursal': idSuc,
              'cantidad': cantidad,
              'codigo_barras': codigo.toString(),
            });
          }
        } catch (_) {
          finalDistribuciones = [{'id_sucursal': branchId, 'cantidad': data['stock'] ?? 1, 'codigo_barras': codigo.toString()}];
        }
      } else {
        finalDistribuciones = [{'id_sucursal': branchId, 'cantidad': data['stock'] ?? 1, 'codigo_barras': codigo.toString()}];
      }

      final formData = FormData();
      formData.fields.addAll([
        MapEntry('nombre', data['nombre'] ?? 'Producto'),
        MapEntry('descripcion', data['descripcion'] ?? ''),
        MapEntry('costo', (data['costo'] ?? 0).toString()),
        MapEntry('precio_venta', (data['precio_venta'] ?? 0).toString()),
        MapEntry('stock', (data['stock'] ?? 1).toString()),
        MapEntry('codigo_barras', codigo.toString()),
        MapEntry('proveedor_id', proveedorId.toString()),
        MapEntry('categoria_id', categoriaId.toString()),
        MapEntry('crear_maestro', 'true'),
        MapEntry('request_id', DateTime.now().microsecondsSinceEpoch.toString()),
        MapEntry('colores', jsonEncode(colores)),
        MapEntry('distribuciones', jsonEncode(finalDistribuciones)),
        if (data['_temp_codigos'] is List && (data['_temp_codigos'] as List).isNotEmpty)
          MapEntry(
            'codigos_adicionales',
            jsonEncode((data['_temp_codigos'] as List).map((c) => {
              'codigo': c.toString(),
              'tipo': 'barras',
              'es_principal': false,
            }).toList()),
          ),
      ]);

      if (imageToUpload != null) {
        formData.files.add(MapEntry(
          'imagen',
          await MultipartFile.fromFile(
            imageToUpload.path,
            filename: imageToUpload.path.split('/').last,
          ),
        ));
      }

      final response = await _dio.post(
        '$BASE_URL/productos/distribucion',
        data: formData,
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final productName = data['nombre'] ?? 'Producto';
        setState(() {
          _registeredCount++;
          _pendingProducts.removeWhere((p) =>
            p['nombre'] == data['nombre'] && p['codigo_barras'] == data['codigo_barras']);
          if (messageIndex != null && messageIndex < _messages.length) {
            _messages[messageIndex] = ChatMessage(
              text: _messages[messageIndex].text,
              isUser: false,
              productData: data,
              isConfirmed: true,
            );
          }
          _messages.add(ChatMessage(
            text: '✓ "$productName" registrado exitosamente',
            isUser: false,
          ));
        });
        _scrollToBottom();
      } else {
        _showError('Error al crear producto');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Error: $e');
    }
  }

  Future<void> _showBatchConfirmDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Registrar ${_pendingProducts.length} producto${_pendingProducts.length != 1 ? 's' : ''}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _pendingProducts.length,
            itemBuilder: (context, index) {
              final p = _pendingProducts[index];
              return ListTile(
                dense: true,
                leading: Icon(Icons.inventory_2, color: const Color(0xFFC026D3), size: 20),
                title: Text(p['nombre'] ?? 'Producto ${index + 1}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13.sp)),
                subtitle: Text('Bs. ${p['precio_venta'] ?? 0}',
                    style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC026D3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Registrar Todo',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final product in _pendingProducts.toList()) {
        await _confirmProduct(product);
      }
    }
  }

  Future<void> _showExitConfirmDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Salir?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        content: Text(
          'Tienes $_registeredCount producto${_registeredCount != 1 ? 's' : ''} registrado${_registeredCount != 1 ? 's' : ''}${_pendingProducts.isNotEmpty ? ' y ${_pendingProducts.length} pendiente${_pendingProducts.length != 1 ? 's' : ''}' : ''}.',
          style: GoogleFonts.poppins(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Seguir', style: GoogleFonts.poppins(color: const Color(0xFFC026D3), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Salir', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Error', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(msg, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioRecordingProvider(),
      child: Consumer<AudioRecordingProvider>(
        builder: (context, audioProv, _) {
          return WillPopScope(
            onWillPop: () async {
              if (_registeredCount > 0 || _pendingProducts.isNotEmpty) {
                await _showExitConfirmDialog();
                return false;
              }
              return true;
            },
            child: Scaffold(
            backgroundColor: const Color(0xFFFDF4FF),
            appBar: AppBar(
              backgroundColor: const Color(0xFFC026D3),
              elevation: 0,
              title: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Asistente AI',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              actions: [
                if (_registeredCount > 0)
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(right: 4.w),
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_registeredCount creado${_registeredCount != 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_pendingProducts.isNotEmpty)
                  Center(
                    child: GestureDetector(
                      onTap: _pendingProducts.length == 1
                          ? () => _confirmProduct(_pendingProducts.first)
                          : _showBatchConfirmDialog,
                      child: Container(
                        margin: EdgeInsets.only(right: 4.w),
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC026D3).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.checklist, color: Colors.white, size: 14),
                            SizedBox(width: 4.w),
                            Text(
                              '${_pendingProducts.length} pendiente${_pendingProducts.length != 1 ? 's' : ''}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availableModels.any((m) => m['id'] == _selectedModel) ? _selectedModel : null,
                      isDense: true,
                      hint: Text('Cargando...', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11.sp)),
                      dropdownColor: const Color(0xFF701A75),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      items: _availableModels.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Text(m['name']!, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.sp)),
                        );
                      }).toList(),
                      onChanged: _availableModels.isEmpty
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedModel = val);
                                audioProv.setSelectedModel(val);
                              }
                            },
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Limpiar chat',
                  onPressed: () {
                    audioProv.reset();
                    _clearChat();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _registeredCount > 0 || _pendingProducts.isNotEmpty
                      ? _showExitConfirmDialog
                      : () => Navigator.pop(context),
                ),
              ],
            ),
            body: Column(
              children: [
                // Recording indicator overlay
                if (audioProv.isRecording)
                  _buildRecordingIndicator(audioProv),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16.w),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, audioProv);
                    },
                  ),
                ),
                if (_pendingImage != null || _scannedBarcode != null)
                  _buildAttachmentsBar(),
                _buildInputBar(audioProv),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  // ===================== RECORDING INDICATOR =====================

  Widget _buildRecordingIndicator(AudioRecordingProvider audioProv) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFC026D3).withOpacity(0.9),
                const Color(0xFFE879F9).withOpacity(0.9),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Grabando... ${audioProv.formattedDuration}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => audioProv.cancelRecording(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================== MESSAGE BUBBLES =====================

  Widget _buildMessageBubble(ChatMessage msg, AudioRecordingProvider audioProv) {
    if (msg.isLoading) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFFC026D3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Analizando con IA...',
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (msg.productData != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: _buildProductPreview(msg, audioProv),
      );
    }

    if (msg.audioData != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: _buildAudioBubble(msg),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: 0.85.sw),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color(0xFFC026D3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: msg.isUser
                      ? Radius.zero
                      : const Radius.circular(16),
                  bottomLeft: msg.isUser
                      ? const Radius.circular(16)
                      : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.imageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        msg.imageFile!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (msg.imageFile != null) const SizedBox(height: 8),
                  Text(
                    msg.text,
                    style: GoogleFonts.poppins(
                      color: msg.isUser ? Colors.white : Colors.black87,
                      fontSize: 13.sp,
                    ),
                  ),
                  if (msg.isError && msg.onRetry != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: msg.onRetry,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC026D3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Reintentar',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== AUDIO BUBBLE (WhatsApp style) =====================

  Widget _buildAudioBubble(ChatMessage msg) {
    final audio = msg.audioData!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 0.75.sw),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE879F9), Color(0xFFC026D3)],
            ),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: Radius.zero,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC026D3).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Waveform placeholder
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(20, (i) {
                      final heights = [3.0, 6.0, 9.0, 12.0, 8.0, 5.0, 10.0, 7.0, 4.0, 11.0,
                          6.0, 9.0, 3.0, 8.0, 12.0, 5.0, 7.0, 10.0, 4.0, 8.0];
                      return Container(
                        width: 2,
                        height: heights[i],
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audio.formattedDuration}  •  ${audio.formattedSize}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== PRODUCT PREVIEW + EDIT FORM =====================

  Widget _buildProductPreview(ChatMessage msg, AudioRecordingProvider audioProv) {
    final data = msg.productData!;
    final colores = data['colores'] is List ? data['colores'] as List : <dynamic>[];
    final camposFaltantes = data['campos_faltantes'] is List ? data['campos_faltantes'] as List : <dynamic>[];

    // If editing mode, show inline form
    if (!msg.isConfirmed && audioProv.viewMode == FormViewMode.editing && audioProv.hasData) {
      return _buildInlineEditForm(audioProv);
    }

    if (msg.isConfirmed) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF22C55E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['nombre'] ?? 'Producto',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  Text('Registrado exitosamente',
                      style: GoogleFonts.poppins(
                          fontSize: 12.sp, color: const Color(0xFF22C55E))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Preview mode
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE879F9).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC026D3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Color(0xFFC026D3), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Producto Interpretado',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ),
            ],
          ),
          if (camposFaltantes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Faltan: ${camposFaltantes.join(", ")}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          _previewRow('Nombre', data['nombre'] ?? ''),
          _previewRow('Descripción', data['descripcion'] ?? ''),
          _previewRow('Categoría', data['categoria'] ?? ''),
          _previewRow('Código', data['codigo_barras'] ?? ''),
          _previewRow('Costo', 'Bs. ${data['costo'] ?? 0}'),
          _previewRow('Precio Venta', 'Bs. ${data['precio_venta'] ?? 0}'),
          _previewRow('Proveedor', data['proveedor'] ?? 'Akzana'),

          // Image section per product
          const Divider(height: 20),
          _buildProductImageSection(data, msg),

          // Additional codes section
          const Divider(height: 12),
          _buildProductCodesSection(data, msg),

          // Binary switch toggles
          const Divider(height: 20),
          _buildBooleanSwitch('Para Venta', _getFlag(data, 'es_para_venta', true),
              () => audioProv.toggleEsParaVenta()),
          _buildBooleanSwitch('Distribución Multi-Sucursal', _getFlag(data, 'distribucion_multi_sucursal', false),
              () => audioProv.toggleDistribucionMultiSucursal()),
          _buildBooleanSwitch('Control de Stock', _getFlag(data, 'control_de_stock', true),
              () => audioProv.toggleControlDeStock()),

          // Multi-branch distribution
          if (data['distribuciones'] is List && (data['distribuciones'] as List).isNotEmpty &&
              (data['distribuciones'] as List).any((d) => d['nombre_sucursal'] != null && d['nombre_sucursal'].toString().isNotEmpty)) ...[
            const Divider(height: 20),
            Text('Distribución por sucursal:',
                style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
            ...((data['distribuciones'] as List).where((d) => d['nombre_sucursal'] != null && d['nombre_sucursal'].toString().isNotEmpty).map((d) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(
                children: [
                  Icon(Icons.store_outlined, size: 13, color: const Color(0xFFC026D3)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${d['nombre_sucursal']}: ${d['cantidad']} uds',
                      style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ))).toList(),
          ] else
            _previewRow('Stock', '${data['stock'] ?? 0}'),

          if (colores.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Colores:',
                style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: colores.map<Widget>((c) {
                final hex = c.toString().replaceAll('#', '');
                final color = Color(int.parse('FF$hex', radix: 16));
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFC026D3)),
                  ),
                  onPressed: () => audioProv.switchToEditing(),
                  icon: const Icon(Icons.edit, size: 18, color: Color(0xFFC026D3)),
                  label: Text('Editar',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC026D3))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC026D3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final idx = _messages.indexOf(msg);
                    _confirmProduct(data, messageIndex: idx);
                  },
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: Text('Confirmar y Crear',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _getFlag(Map<String, dynamic> data, String key, bool defaultVal) {
    return data[key] ?? defaultVal;
  }

  Widget _buildBooleanSwitch(String label, bool value, VoidCallback onToggle) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700)),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: value ? const Color(0xFFC026D3) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageSection(Map<String, dynamic> data, ChatMessage msg) {
    final imagePath = data['_temp_image'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto del Producto',
            style: GoogleFonts.poppins(
                fontSize: 11.sp, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        if (imagePath != null && imagePath.isNotEmpty)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    data['_temp_image'] = null;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _pickImageForProduct(data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Cambiar',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: () => _pickImageForProduct(data),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 28),
                  const SizedBox(height: 6),
                  Text('Agregar Foto',
                      style: GoogleFonts.poppins(
                          fontSize: 12.sp, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImageForProduct(Map<String, dynamic> data) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Añadir Imagen',
                style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(Icons.camera_alt, 'Cámara', Colors.pink, () {
                  Navigator.pop(context);
                  _takePhotoForProduct(data, ImageSource.camera);
                }),
                _photoOption(Icons.image, 'Galería', Colors.blue, () {
                  Navigator.pop(context);
                  _takePhotoForProduct(data, ImageSource.gallery);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhotoForProduct(Map<String, dynamic> data, ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (photo != null) {
      setState(() {
        data['_temp_image'] = photo.path;
      });
    }
  }

  Widget _buildProductCodesSection(Map<String, dynamic> data, ChatMessage msg) {
    final codigos = data['_temp_codigos'] as List<String>? ?? [];
    final principal = data['codigo_barras']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Códigos',
            style: GoogleFonts.poppins(
                fontSize: 11.sp, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        if (principal.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFC026D3).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code, size: 14, color: const Color(0xFFC026D3)),
                const SizedBox(width: 6),
                Text(principal,
                    style: GoogleFonts.robotoMono(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('(principal)',
                    style: GoogleFonts.poppins(fontSize: 9.sp, color: Colors.grey)),
              ],
            ),
          ),
        if (codigos.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...codigos.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(codigos[e.key],
                            style: GoogleFonts.robotoMono(fontSize: 11.sp))),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          data['_temp_codigos'].removeAt(e.key);
                        });
                      },
                      child: const Icon(Icons.close, size: 14, color: Colors.red),
                    ),
                  ],
                ),
              )),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _scanCodeForProduct(data),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFC026D3).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC026D3).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, size: 16, color: const Color(0xFFC026D3)),
                const SizedBox(width: 6),
                Text('Escanear otro código',
                    style: GoogleFonts.poppins(
                        fontSize: 11.sp, fontWeight: FontWeight.w500, color: const Color(0xFFC026D3))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _scanCodeForProduct(Map<String, dynamic> data) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
    if (result != null && result.toString().isNotEmpty) {
      setState(() {
        final codigos = data['_temp_codigos'] as List<String>? ?? [];
        codigos.add(result.toString());
        data['_temp_codigos'] = codigos;
      });
    }
  }

  // ===================== INLINE EDIT FORM =====================

  Widget _buildInlineEditForm(AudioRecordingProvider audioProv) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC026D3).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC026D3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note,
                    color: Color(0xFFC026D3), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Editar Producto',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ),
              GestureDetector(
                onTap: () => audioProv.switchToPreview(),
                child: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Divider(height: 24),

          // Form fields
          _editField('Nombre', audioProv.nombreController, Icons.label_outline),
          _editField('Descripción', audioProv.descripcionController, Icons.description_outlined, maxLines: 2),
          _editField('Costo (Bs.)', audioProv.costoController, Icons.attach_money, keyboardType: TextInputType.number),
          _editField('Precio Venta (Bs.)', audioProv.precioVentaController, Icons.sell_outlined, keyboardType: TextInputType.number),
          _editField('Stock', audioProv.stockController, Icons.inventory_2_outlined, keyboardType: TextInputType.number),
          _editField('Código de Barras', audioProv.codigoController, Icons.qr_code),

          // Dropdown selectors
          const SizedBox(height: 8),
          _buildDropdownSelector(
            'Categoría',
            audioProv.categoriaController.text,
            audioProv.categorias,
            (val) => audioProv.updateCategoria(val),
          ),
          _buildDropdownSelector(
            'Proveedor',
            audioProv.proveedorController.text,
            audioProv.proveedores,
            (val) => audioProv.updateProveedor(val),
          ),

          // Boolean switches
          const Divider(height: 20),
          _buildBooleanSwitch('Para Venta', audioProv.esParaVenta,
              () => audioProv.toggleEsParaVenta()),
          _buildBooleanSwitch('Distribución Multi-Sucursal', audioProv.distribucionMultiSucursal,
              () => audioProv.toggleDistribucionMultiSucursal()),
          _buildBooleanSwitch('Control de Stock', audioProv.controlDeStock,
              () => audioProv.toggleControlDeStock()),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFC026D3)),
                  ),
                  onPressed: () => audioProv.switchToPreview(),
                  icon: const Icon(Icons.visibility, size: 18, color: Color(0xFFC026D3)),
                  label: Text('Vista Previa',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC026D3))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC026D3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final editedData = audioProv.getCurrentFormData();
                    _confirmProduct(editedData.toJson());
                  },
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: Text('Confirmar y Crear',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(fontSize: 13.sp),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFFC026D3)),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC026D3), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDropdownSelector(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    final matchInOptions = options.firstWhere(
      (o) => o.toLowerCase() == currentValue.toLowerCase(),
      orElse: () => '',
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: DropdownButtonFormField<String>(
        initialValue: matchInOptions.isNotEmpty ? matchInOptions : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: Colors.grey.shade500,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC026D3), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          isDense: true,
        ),
        items: options.map((o) {
          return DropdownMenuItem<String>(
            value: o,
            child: Text(o, style: GoogleFonts.poppins(fontSize: 13.sp)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ===================== ATTACHMENTS & INPUT =====================

  Widget _buildAttachmentsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: Colors.white,
      child: Row(
        children: [
          if (_pendingImage != null)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      _pendingImage!,
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _pendingImage = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ],
              ),
            ),
          if (_pendingImage != null) const SizedBox(width: 8),
          if (_scannedBarcode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(_scannedBarcode!,
                      style: GoogleFonts.robotoMono(fontSize: 11.sp)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _scannedBarcode = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AudioRecordingProvider audioProv) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Action buttons (camera, barcode)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(LineIcons.camera, () => _pickImage()),
                  _iconBtn(LineIcons.barcode, () => _scanCode()),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Text input
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 120.h),
                child: TextField(
                  controller: _textController,
                  style: GoogleFonts.poppins(fontSize: 13.sp),
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Describe el producto...',
                    hintStyle:
                        GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13.sp),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: _isProcessing ? null : _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE879F9), Color(0xFFC026D3)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC026D3).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isProcessing ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Mic button (WhatsApp style press-and-hold)
            GestureDetector(
              onTapDown: (_) => _onMicTapDown(audioProv),
              onTapUp: (_) => _onMicTapUp(audioProv),
              onTapCancel: () => _onMicTapCancel(audioProv),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final isActive = audioProv.isRecording;
                  return Transform.scale(
                    scale: isActive ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.red
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        isActive ? Icons.mic : Icons.mic_none,
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20, color: Colors.grey.shade600),
      ),
    );
  }
}
