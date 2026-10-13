import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class LocalConnectionProvider extends ChangeNotifier {
  Socket? _socket;
  bool _isConnected = false;
  String _localHost = '192.168.1.100';
  int _localPort = 5000;
  String _errorMessage = '';
  String _userName = '';
  List<dynamic> _localProducts = [];
  late final Dio _dio;

  LocalConnectionProvider() {
    _dio = Dio(
      BaseOptions(
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  bool get isConnected => _isConnected;
  String get localHost => _localHost;
  int get localPort => _localPort;
  String get errorMessage => _errorMessage;
  String get userName => _userName;
  List<dynamic> get localProducts => _localProducts;
  
  late String _httpBaseUrl;
  String get httpBaseUrl => _httpBaseUrl;
  
  List<dynamic> _localCategories = [];
  List<dynamic> _localProviders = [];
  List<dynamic> _localBranches = [];
  
  List<dynamic> get localCategories => _localCategories;
  List<dynamic> get localProviders => _localProviders;
  List<dynamic> get localBranches => _localBranches;

  void setLocalHost(String host) {
    _localHost = host;
    notifyListeners();
  }

  void setLocalPort(int port) {
    _localPort = port;
    notifyListeners();
  }

  Future<bool> connectToLocalServer(String userName) async {
    try {
      _errorMessage = '';
      _userName = userName;
      
      _socket = await Socket.connect(_localHost, _localPort, timeout: const Duration(seconds: 5));
      
      final connectData = {
        'usuario': userName,
        'tipo': 'app_connect',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _socket!.write(jsonEncode(connectData) + 'EOF_JSON');
      await _socket!.flush();
      
      _isConnected = true;
      notifyListeners();
      
      _socket!.listen(
        (data) {
        },
        onError: (error) {
          _handleConnectionLoss();
        },
        onDone: () {
          _handleConnectionLoss();
        },
      );
      
      return true;
    } on SocketException catch (e) {
      _isConnected = false;
      _errorMessage = 'Error de conexión: ${e.message}';
      notifyListeners();
      return false;
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  void _handleConnectionLoss() {
    _isConnected = false;
    _socket = null;
    _userName = '';
    _localProducts = [];
    _localCategories = [];
    _localProviders = [];
    _localBranches = [];
    _errorMessage = 'Conexión perdida';
    notifyListeners();
  }

  Future<List<dynamic>> fetchLocalProducts() async {
    try {
      _errorMessage = '';
      final url = 'http://$_localHost:8000/api/productos';
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        _localProducts = response.data ?? [];
        notifyListeners();
        return _localProducts;
      }
      return [];
    } on DioException catch (e) {
      _errorMessage = 'Error al cargar productos: ${e.message}';
      notifyListeners();
      return [];
    } catch (e) {
      _errorMessage = 'Error: $e';
      notifyListeners();
      return [];
    }
  }

  Future<List<dynamic>> fetchLocalCategories() async {
    try {
      _errorMessage = '';
      final url = 'http://$_localHost:8000/api/categorias';
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        _localCategories = response.data ?? [];
        notifyListeners();
        return _localCategories;
      }
      return [];
    } on DioException catch (e) {
      _errorMessage = 'Error al cargar categorías: ${e.message}';
      notifyListeners();
      return [];
    } catch (e) {
      _errorMessage = 'Error: $e';
      notifyListeners();
      return [];
    }
  }

  Future<List<dynamic>> fetchLocalProviders() async {
    try {
      _errorMessage = '';
      final url = 'http://$_localHost:8000/api/proveedores';
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        _localProviders = response.data ?? [];
        notifyListeners();
        return _localProviders;
      }
      return [];
    } on DioException catch (e) {
      _errorMessage = 'Error al cargar proveedores: ${e.message}';
      notifyListeners();
      return [];
    } catch (e) {
      _errorMessage = 'Error: $e';
      notifyListeners();
      return [];
    }
  }

  Future<List<dynamic>> fetchLocalBranches() async {
    try {
      _errorMessage = '';
      final url = 'http://$_localHost:8000/api/sucursales';
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        _localBranches = response.data ?? [];
        notifyListeners();
        return _localBranches;
      }
      return [];
    } on DioException catch (e) {
      _errorMessage = 'Error al cargar sucursales: ${e.message}';
      notifyListeners();
      return [];
    } catch (e) {
      _errorMessage = 'Error: $e';
      notifyListeners();
      return [];
    }
  }

  Future<bool> sendProductToLocal(Map<String, dynamic> producto, {File? imagenFile}) async {
    try {
      if (!_isConnected || _socket == null) {
        _errorMessage = 'No hay conexión con servidor local';
        return false;
      }

      final productData = {
        'tipo': 'producto',
        'nombre': producto['nombre'],
        'codigo_barras': producto['codigo_barras'],
        'id_sucursal': producto['id_sucursal'],
        'descripcion': producto['descripcion'] ?? '',
        'stock': producto['stock'] ?? 0,
        'precio_venta': producto['precio_venta'] ?? 0,
        'costo': producto['costo'] ?? 0,
        'categoria_id': producto['categoria_id'],
        'proveedor_id': producto['proveedor_id'],
        'timestamp': DateTime.now().toIso8601String(),
        'usuario': _userName,
      };

      if (imagenFile != null && imagenFile.existsSync()) {
        try {
          final imageBytes = await imagenFile.readAsBytes();
          productData['imagen_raw'] = imageBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        } catch (e) {
          // Error procesando imagen - continuar sin imagen
        }
      }

      _socket!.write(jsonEncode(productData) + 'EOF_JSON');
      await _socket!.flush();
      return true;
    } catch (e) {
      _errorMessage = 'Error enviando producto: $e';
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_socket != null) {
        await _socket!.close();
      }
      _isConnected = false;
      _userName = '';
      _localProducts = [];
      _localCategories = [];
      _localProviders = [];
      _localBranches = [];
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
