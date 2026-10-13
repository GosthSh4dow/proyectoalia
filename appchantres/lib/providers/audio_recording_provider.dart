import 'package:flutter/material.dart';
import '../models/product_form_data.dart';
import '../servicios/audio_service.dart';

enum AudioState {
  idle,
  recording,
  sending,
  success,
  error,
}

enum FormViewMode {
  preview,
  editing,
}

class AudioRecordingProvider extends ChangeNotifier {
  final AudioRecordingService _audioService = AudioRecordingService();

  // --- Audio state ---
  AudioState _audioState = AudioState.idle;
  int _recordingDuration = 0;
  String _selectedModel = 'glm-5.1';

  // --- Form data from backend ---
  ProductFormData? _productData;
  String? _errorMessage;
  String? _chatContext;

  // --- Form view mode ---
  FormViewMode _viewMode = FormViewMode.preview;

  // --- Text controllers (editable form) ---
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController costoController = TextEditingController();
  final TextEditingController precioVentaController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController codigoController = TextEditingController();
  final TextEditingController categoriaController = TextEditingController();
  final TextEditingController proveedorController = TextEditingController();

  // --- Boolean flags (binary switches) ---
  bool _esParaVenta = true;
  bool _distribucionMultiSucursal = false;
  bool _controlDeStock = true;

  // --- Selectors state ---
  List<String> _categorias = [];
  List<String> _proveedores = [];
  List<String> _coloresSeleccionados = [];

  // --- Getters ---
  AudioState get audioState => _audioState;
  int get recordingDuration => _recordingDuration;
  String get selectedModel => _selectedModel;
  ProductFormData? get productData => _productData;
  String? get errorMessage => _errorMessage;
  FormViewMode get viewMode => _viewMode;
  bool get esParaVenta => _esParaVenta;
  bool get distribucionMultiSucursal => _distribucionMultiSucursal;
  bool get controlDeStock => _controlDeStock;
  List<String> get categorias => _categorias;
  List<String> get proveedores => _proveedores;
  List<String> get coloresSeleccionados => _coloresSeleccionados;
  bool get isRecording => _audioState == AudioState.recording;
  bool get isSending => _audioState == AudioState.sending;
  bool get hasData => _productData != null && _productData!.tieneDatos;

  String get formattedDuration {
    final min = _recordingDuration ~/ 60;
    final sec = _recordingDuration % 60;
    return min > 0
        ? '$min:${sec.toString().padLeft(2, '0')}'
        : '0:${sec.toString().padLeft(2, '0')}';
  }

  // --- Initialization ---
  void initialize({
    List<String> categoriasDisponibles = const [],
    List<String> proveedoresDisponibles = const [],
  }) {
    _categorias = categoriasDisponibles;
    _proveedores = proveedoresDisponibles;
  }

  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  void setChatContext(String? context) {
    _chatContext = context;
  }

  // --- Recording lifecycle ---
  Future<void> startRecording() async {
    try {
      if (!await _audioService.hasPermission()) {
        _setError('Permiso de micrófono no concedido');
        return;
      }
      _audioState = AudioState.recording;
      _recordingDuration = 0;
      _clearError();
      notifyListeners();

      await _audioService.startRecording(
        onDurationUpdate: (seconds) {
          _recordingDuration = seconds;
          notifyListeners();
        },
      );
    } catch (e) {
      _setError('Error al iniciar grabación: $e');
    }
  }

  Future<void> stopRecordingAndProcess() async {
    if (_audioState != AudioState.recording) return;

    _audioState = AudioState.sending;
    _recordingDuration = 0;
    notifyListeners();

    try {
      final result = await _audioService.stopRecordingAndSend(
        modelo: _selectedModel,
        contexto: _chatContext,
      );

      _productData = result.productData;
      _audioState = AudioState.success;
      _viewMode = FormViewMode.preview;

      // Inject data into controllers
      _injectDataToControllers(result.productData);
      _applyBooleanFlags(result.productData);

      // Update chat context for follow-up refinements
      _chatContext = result.productData.toJson().toString();

      notifyListeners();
    } catch (e) {
      _setError('Error al procesar audio: $e');
    }
  }

  Future<void> cancelRecording() async {
    await _audioService.cancelRecording();
    _audioState = AudioState.idle;
    _recordingDuration = 0;
    notifyListeners();
  }

  // --- Data injection into controllers ---
  void _injectDataToControllers(ProductFormData data) {
    nombreController.text = data.nombre;
    descripcionController.text = data.descripcion;
    costoController.text = data.costo > 0 ? data.costo.toStringAsFixed(2) : '';
    precioVentaController.text =
        data.precioVenta > 0 ? data.precioVenta.toStringAsFixed(2) : '';
    stockController.text = data.stock > 0 ? data.stock.toString() : '';
    codigoController.text = data.codigoBarras;
    categoriaController.text = data.categoria;
    proveedorController.text = data.proveedor;
    _coloresSeleccionados = List.from(data.colores);

    // Auto-match selectors with available options
    _autoMatchSelectors(data);
  }

  void _autoMatchSelectors(ProductFormData data) {
    if (data.categoria.isNotEmpty) {
      final match = _categorias.firstWhere(
        (c) => c.toLowerCase() == data.categoria.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        categoriaController.text = match;
      }
    }

    if (data.proveedor.isNotEmpty) {
      final match = _proveedores.firstWhere(
        (p) => p.toLowerCase() == data.proveedor.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        proveedorController.text = match;
      }
    }
  }

  // --- Boolean flags (binary switches) ---
  void _applyBooleanFlags(ProductFormData data) {
    _esParaVenta = data.esParaVenta;
    _distribucionMultiSucursal = data.distribucionMultiSucursal;
    _controlDeStock = data.controlDeStock;
  }

  void toggleEsParaVenta() {
    _esParaVenta = !_esParaVenta;
    _syncFlagsToData();
    notifyListeners();
  }

  void toggleDistribucionMultiSucursal() {
    _distribucionMultiSucursal = !_distribucionMultiSucursal;
    _syncFlagsToData();
    notifyListeners();
  }

  void toggleControlDeStock() {
    _controlDeStock = !_controlDeStock;
    _syncFlagsToData();
    notifyListeners();
  }

  void _syncFlagsToData() {
    if (_productData != null) {
      _productData!.esParaVenta = _esParaVenta;
      _productData!.distribucionMultiSucursal = _distribucionMultiSucursal;
      _productData!.controlDeStock = _controlDeStock;
    }
  }

  // --- View mode switching ---
  void switchToEditing() {
    _viewMode = FormViewMode.editing;
    notifyListeners();
  }

  void switchToPreview() {
    _viewMode = FormViewMode.preview;
    notifyListeners();
  }

  // --- Selectors update ---
  void updateCategoria(String? value) {
    if (value != null) {
      categoriaController.text = value;
      _productData?.categoria = value;
      notifyListeners();
    }
  }

  void updateProveedor(String? value) {
    if (value != null) {
      proveedorController.text = value;
      _productData?.proveedor = value;
      notifyListeners();
    }
  }

  void updateColores(List<String> colors) {
    _coloresSeleccionados = colors;
    _productData?.colores = colors;
    notifyListeners();
  }

  // --- Get current form data (edited by user) ---
  ProductFormData getCurrentFormData() {
    return ProductFormData(
      nombre: nombreController.text.trim(),
      descripcion: descripcionController.text.trim(),
      costo: double.tryParse(costoController.text) ?? 0,
      precioVenta: double.tryParse(precioVentaController.text) ?? 0,
      stock: int.tryParse(stockController.text) ?? 1,
      codigoBarras: codigoController.text.trim(),
      categoria: categoriaController.text.trim(),
      proveedor: proveedorController.text.trim(),
      colores: _coloresSeleccionados,
      distribuciones: _productData?.distribuciones ?? [],
      esParaVenta: _esParaVenta,
      distribucionMultiSucursal: _distribucionMultiSucursal,
      controlDeStock: _controlDeStock,
    );
  }

  // --- Reset ---
  void reset() {
    _audioState = AudioState.idle;
    _recordingDuration = 0;
    _productData = null;
    _errorMessage = null;
    _viewMode = FormViewMode.preview;
    _esParaVenta = true;
    _distribucionMultiSucursal = false;
    _controlDeStock = true;
    _coloresSeleccionados = [];
    _chatContext = null;
    nombreController.clear();
    descripcionController.clear();
    costoController.clear();
    precioVentaController.clear();
    stockController.clear();
    codigoController.clear();
    categoriaController.clear();
    proveedorController.clear();
    notifyListeners();
  }

  // --- Error handling ---
  void _setError(String message) {
    _errorMessage = message;
    _audioState = AudioState.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    nombreController.dispose();
    descripcionController.dispose();
    costoController.dispose();
    precioVentaController.dispose();
    stockController.dispose();
    codigoController.dispose();
    categoriaController.dispose();
    proveedorController.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
