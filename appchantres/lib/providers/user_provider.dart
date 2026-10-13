import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../api.dart';
import '../servicios/api_service.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic> _user = {};
  String _token = '';
  String _refreshToken = '';
  bool _isAuthenticated = false;
  List<dynamic> _sucursales = [];

  // Campos para coincidir con UserContext.js de React
  Map<String, dynamic>? _branch;
  int? _userId;
  int? _branchId;

  // Ya no necesitamos una instancia privada de Dio, usamos ApiService
  final Dio _dio = ApiService().dio;

  // Constructor que configura el ApiService
  UserProvider() {
    _setupApiService();
  }

  void _setupApiService() {
    final apiService = ApiService();
    
    // Configurar callbacks para que ApiService informe al Provider
    apiService.onLogoutRequired = () async {
      print("ApiService reportó que se requiere logout (renovación fallida)");
      await logout();
    };
    
    apiService.onTokenUpdated = (newToken) async {
      print("ApiService reportó un nuevo token: $newToken");
      _token = newToken;
      await _saveUserData();
      notifyListeners();
    };
  }

  // El método _setupDioInterceptors ha sido deprecado en favor de ApiService

  // Getters
  Map<String, dynamic> get user => _user;
  String get token => _token;
  String get refreshToken => _refreshToken;
  bool get isAuthenticated => _isAuthenticated;
  List<dynamic> get sucursales => _sucursales;
  Map<String, dynamic>? get branch => _branch;
  int? get userId => _userId;
  int? get branchId => _branchId;
  bool get isAdmin => _user['rol']?.toString().toLowerCase() == 'administrador';

  // El método _renewToken ahora es gestionado internamente por ApiService

  // Método principal para login
  Future<bool> login(String email, String password, String apiUrl) async {
    try {
      final response = await ApiService().dio.post(
        getApiUrl('auth/login'),
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Extraer datos exactamente como vienen de la API
        final token = response.data['token'];
        final refreshToken =
            response.data['refreshToken'];
        final userData = response.data['usuario'];
        final sucursales = response.data['sucursales'] ?? [];

        print('🔐 Login response - Sucursales en respuesta: ${sucursales.length}');
        print('👥 Usuario en respuesta: ${userData['nombre']}, Rol: ${userData['rol']}');

        return await loginWithData(token, refreshToken, userData, sucursales);
      }

      return false;
    } catch (e) {
      print('Error durante el login: $e');
      return false;
    }
  }

  // Método para iniciar sesión con datos ya obtenidos (actualizado para incluir refresh token)
  Future<bool> loginWithData(String token, String refreshToken,
      Map<String, dynamic> userData, List<dynamic> sucursalesData) async {
    try {
      _token = token;
      _refreshToken = refreshToken;
      _user = userData;
      _sucursales = sucursalesData;
      _isAuthenticated = true;

      _branch = userData['sucursal'];
      _userId = userData['id'];
      _branchId = userData['id_sucursal'];

      print('🏢 Sucursal actual: ${_branch?['nombre']}');

      // Sincronizar tokens con ApiService
      ApiService().updateTokens(_token, _refreshToken);

      await _saveUserData();

      notifyListeners();
      return true;
    } catch (e) {
      print('Error al guardar datos de usuario: $e');
      return false;
    }
  }

  // Método para cerrar sesión
  Future<void> logout() async {
    try {
      // Intentar notificar al servidor sobre el logout
      if (_refreshToken.isNotEmpty) {
        await _dio
            .post('$BASE_URL/auth/logout',
                data: {'refreshToken': _refreshToken},
                options: Options(headers: {'Authorization': 'Bearer $_token'}))
            .catchError((e) {
          print('Error al notificar logout: $e');
        });
      }
    } catch (e) {
      print('Error durante logout: $e');
    } finally {
      // Limpiar datos locales independientemente del resultado
      _user = {};
      _token = '';
      _userId = null;
      _branchId = null;

      // Limpiar tokens en ApiService
      ApiService().updateTokens(null, null);

      // Limpiar datos de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      await prefs.remove('token');
      await prefs.remove('refreshToken');
      await prefs.remove('sucursales');
      await prefs.remove('authToken');

      notifyListeners();
    }
  }

  // Método para verificar si hay una sesión guardada
  Future<bool> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();

    String? userToken =
        prefs.getString('authToken') ?? prefs.getString('token');
    String? userRefreshToken = prefs.getString('refreshToken');

    if (userToken != null && userToken.isNotEmpty) {
      String? userDataStr = prefs.getString('user');

      if (userDataStr != null) {
        try {
          final userData = json.decode(userDataStr);

          _user = userData;
          _token = userToken;
          _refreshToken = userRefreshToken ?? '';
          // _isAuthenticated se establecerá después de la validación del token

          _branch = userData['sucursal'];
          _userId = userData['id'];
          _branchId = userData['id_sucursal'];

          _dio.options.headers["Authorization"] = "Bearer $_token";

          final sucursalesStr = prefs.getString('sucursales');
          if (sucursalesStr != null) {
            _sucursales = json.decode(sucursalesStr);
          }
          
          // Ensure _branch is populated if validation was skipped or data incomplete
          if (_branch == null && _branchId != null && _sucursales.isNotEmpty) {
             try {
                final found = _sucursales.firstWhere((s) => s['id'] == _branchId, orElse: () => null);
                if (found != null) {
                  _branch = found;
                }
             } catch (_) {}
          }

          bool tokenIsValid = await _checkAndRenewTokenIfNeeded();
          if (tokenIsValid) {
            _isAuthenticated = true;
            notifyListeners();
            return true;
          } else {
            // _checkAndRenewTokenIfNeeded ya llama a logout si la renovación falla
            _isAuthenticated = false;
            // No notificar listeners aquí, logout ya lo hace
            return false;
          }
        } catch (e) {
          print('Error al decodificar datos del usuario durante checkAuth: $e');
          await logout(); // Limpiar si hay error de decodificación
          return false;
        }
      }
    }
    _isAuthenticated = false; // Asegurar que esté falso si no hay token/datos
    return false;
  }

  // Nuevo método para verificar y renovar token si es necesario
  Future<bool> _checkAndRenewTokenIfNeeded() async {
    if (_token.isEmpty) {
      print("_checkAndRenewTokenIfNeeded: No hay token.");
      return false;
    }

    try {
      print("Validando token existente...");
      // Esta llamada usará el interceptor, que añadirá el token desde _dio.options.headers o _token
      await _dio.get('$BASE_URL/auth/validate');
      print("Token existente es válido.");
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        print(
            'Token expirado durante _checkAndRenewTokenIfNeeded, refrescando vía ApiService...');
        if (_refreshToken.isNotEmpty) {
          // El interceptor de ApiService detectará el 401 y renovará, 
          // pero aquí queremos forzarlo si validate falló.
          // Simplemente llamamos a logout si falla la validación crítica inicial
          // o dejamos que el sistema intente una renovación pasiva.
          await logout(); 
          return false;
        } else {
          print("No hay refresh token para intentar la renovación.");
          await logout(); // No hay refresh token, logout
          return false;
        }
      }
      print('Error inesperado validando token: $e');
      await logout();
      return false;
    }
  }

  // Método para guardar los datos del usuario en SharedPreferences
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar en ambos formatos (React y Flutter)
    await prefs.setString('user', json.encode(_user));
    await prefs.setString('token', _token);
    await prefs.setString(
        'refreshToken', _refreshToken); // Nuevo: guardar refresh token
    await prefs.setString(
        'authToken', _token); // También guardar como authToken para React
    await prefs.setString('sucursales', json.encode(_sucursales));

    // Guardar IDs por separado (formato de React)
    if (_userId != null) {
      await prefs.setString('id_usuario', _userId.toString());
    }

    if (_branchId != null) {
      await prefs.setString('id_sucursal', _branchId.toString());
    }
  }

  // Método para actualizar el usuario
  void updateUser(Map<String, dynamic> userData) {
    _user = userData;

    // Actualizar campos adicionales
    _branch = userData['sucursal'];
    _userId = userData['id'];
    _branchId = userData['id_sucursal'];

    _saveUserData();
    notifyListeners();
  }

  // Método para seleccionar una sucursal por ID (busca en sucursales)
  void selectSucursal(int sucursalId, {Map<String, dynamic>? sucursalData}) {
    print('🔄 selectSucursal llamado con ID: $sucursalId');
    print('📋 Sucursales disponibles en provider: ${_sucursales.length}');
    print('📍 Datos de sucursal recibidos: ${sucursalData != null ? sucursalData['nombre'] : 'NO'}');
    
    _user['id_sucursal'] = sucursalId;
    _branchId = sucursalId;
    
    // Usar los datos de sucursal si se proporcionan, de lo contrario buscar
    if (sucursalData != null) {
      print('✅ Usando datos de sucursal recibidos: ${sucursalData['nombre']}');
      _branch = sucursalData;
      _user['sucursal'] = sucursalData;
    } else {
      // Try to find in _sucursales
      try {
        final selectedBranch = _sucursales.firstWhere(
          (s) => s['id'] == sucursalId, 
          orElse: () => null
        );
        if (selectedBranch != null) {
          print('✅ Sucursal encontrada en provider: ${selectedBranch['nombre']}');
          _branch = selectedBranch;
          _user['sucursal'] = selectedBranch;
        } else {
          print('❌ Sucursal NO encontrada con ID: $sucursalId');
        }
      } catch (e) {
        print("❌ Error updating branch object: $e");
      }
    }
    
    _saveUserData();
    print('🔔 Llamando a notifyListeners()');
    notifyListeners();
    print('✅ notifyListeners() completado');
  }

  // Método para actualizar la sucursal actual con un objeto completo
  void updateBranch(Map<String, dynamic> branchData) {
    _branch = branchData;
    _branchId = branchData['id'];
    if (_user.isNotEmpty) {
      _user['id_sucursal'] = _branchId;
      _user['sucursal'] = branchData;
    }
    _saveUserData();
    notifyListeners();
  }

  // Método equivalente a setUserData de React
  void setUserData(Map<String, dynamic> userData) {
    _user = userData;
    _branch = userData['sucursal'];
    _userId = userData['id'];
    _branchId = userData['id_sucursal'];
    _saveUserData();
    notifyListeners();
  }

  // Método equivalente a clearUserData de React
  Future<void> clearUserData() async {
    await logout();
  }

  // Métodos para realizar solicitudes HTTP usando la instancia _dio del provider
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) {
    return _dio.get<T>(path,
        queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Options? options}) {
    return _dio.post<T>(path, data: data, options: options);
  }

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) {
    return _dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data, Options? options}) {
    return _dio.delete<T>(path, data: data, options: options);
  }
}
