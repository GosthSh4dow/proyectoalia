import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_background/animated_background.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/user_provider.dart';
import 'api.dart';
import 'servicios/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _showNotification = false;
  bool _passwordVisible = false;
  String? _errorMessage;
  final Dio _dio = ApiService().dio;
  
  // Controladores de animación
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
    // Iniciar animaciones después de un delay
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Ocultar el teclado
    FocusScope.of(context).unfocus();
    
    // Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    
    try {
      // Realizar la petición al API
      final response = await _dio.post(
        getApiUrl('auth/login'),
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
      
      if (response.statusCode == 200) {
        // Extraer los datos de la respuesta
        final token = response.data['token'];
        final refreshToken = response.data['refreshToken']; // Nuevo: extraemos el refresh token
        final userData = response.data['usuario'];
        final sucursales = response.data['sucursales'] ?? [];
        
        // Actualizar el provider con ambos tokens
        await userProvider.loginWithData(token, refreshToken, userData, sucursales);
        
        setState(() {
          _showNotification = true;
          _loading = false;
        });
        
        // Mostrar notificación de éxito y navegar al dashboard
        _showSuccessNotification();
      }
    } catch (error) {
      setState(() {
        _loading = false;
      });
      
      String message = 'Error al iniciar sesión';
      
      if (error is DioException) {
        if (error.response?.statusCode == 401) {
          message = 'Credenciales incorrectas';
        } else if (error.response?.data?['error'] != null) {
          message = error.response?.data?['error'];
        }
      }
      
      _showErrorMessage(message);
    }
  }
  
  void _showSuccessNotification() {
    setState(() {
      _showNotification = true;
    });
    
    // Mostramos la notificación durante 2 segundos
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showNotification = false);
        
        // Navegar al dashboard con una transición suave
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }
  
  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AwesomeSnackbarContent(
          title: 'Error',
          message: message,
          contentType: ContentType.failure,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado elegante
          AnimatedBackground(
            behaviour: RandomParticleBehaviour(
              options: ParticleOptions(
                baseColor: Colors.white,
                spawnOpacity: 0.1,
                opacityChangeRate: 0.15,
                minOpacity: 0.08,
                maxOpacity: 0.3,
                particleCount: 50,
                spawnMaxRadius: 8,
                spawnMinRadius: 3,
                spawnMaxSpeed: 40,
                spawnMinSpeed: 20,
              ),
            ),
            vsync: this,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF500A2), Color(0xFF800080)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          
          // Contenido principal con animación
          FadeTransition(
            opacity: _fadeController,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo animado
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.5),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: Curves.easeOutQuart,
                          )),
                          child: Hero(
                            tag: 'logo',
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Image.asset('assets/images/logo.jpeg')
                                .animate()
                                .fade(duration: 800.ms, delay: 300.ms)
                                .scale(delay: 300.ms),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Título de la aplicación
                        Text(
                          "CHANNELS",
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fade(duration: 600.ms, delay: 400.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
                        
                        const SizedBox(height: 50),
                        
                        // Tarjeta de login moderna
                        Container(
                          width: min(size.width * 0.9, 400),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.08),
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Título del formulario
                                      Text(
                                        "Iniciar Sesión",
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                      .animate()
                                      .fade(duration: 400.ms, delay: 500.ms)
                                      .slideX(begin: -0.1, end: 0),
                                      
                                      const SizedBox(height: 8),
                                      
                                      // Subtítulo
                                      Text(
                                        "Ingresa tus credenciales para continuar",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      )
                                      .animate()
                                      .fade(duration: 400.ms, delay: 600.ms)
                                      .slideX(begin: -0.1, end: 0),
                                      
                                      const SizedBox(height: 30),
                                      
                                      // Campo de email
                                      _buildAnimatedTextField(
                                        controller: _emailController,
                                        labelText: 'Correo electrónico',
                                        prefixIcon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Por favor ingrese su correo electrónico';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Ingrese un correo electrónico válido';
                                          }
                                          return null;
                                        },
                                        delay: 700,
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // Campo de contraseña
                                      _buildAnimatedTextField(
                                        controller: _passwordController,
                                        labelText: 'Contraseña',
                                        prefixIcon: Icons.lock_outline,
                                        isPassword: true,
                                        passwordVisible: _passwordVisible,
                                        onTogglePassword: () {
                                          setState(() {
                                            _passwordVisible = !_passwordVisible;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Por favor ingrese su contraseña';
                                          }
                                          return null;
                                        },
                                        delay: 800,
                                      ),
                                      
                                      // Mensaje de error
                                      if (_errorMessage != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.red.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.error_outline,
                                                  color: Colors.red[300],
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _errorMessage!,
                                                    style: TextStyle(
                                                      color: Colors.red[300],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Olvidaste contraseña a la derecha
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Por favor contacta a soporte para restablecer tu contraseña'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white.withOpacity(0.9),
                                          ),
                                          child: const Text(
                                            "¿Olvidaste tu contraseña?",
                                            style: TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .fade(duration: 400.ms, delay: 900.ms),
                                      
                                      const SizedBox(height: 30),
                                      
                                      // Botón de inicio de sesión animado
                                      _buildAnimatedButton(
                                        onPressed: _loading ? null : _login,
                                        isLoading: _loading,
                                        delay: 1000,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fade(duration: 800.ms, delay: 300.ms)
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Notificación de éxito
          if (_showNotification)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _slideController,
                    curve: Curves.easeOutBack,
                  )),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "¡Éxito!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Inicio de sesión exitoso",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Pie de página
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeController,
              child: Center(
                child: Text(
                  "© 2025 Channels - Todos los derechos reservados",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget para crear campos de texto animados
  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool? passwordVisible,
    Function()? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required int delay,
  }) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: delay.ms),
        SlideEffect(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
          curve: Curves.easeOutQuad,
          duration: 400.ms,
          delay: delay.ms,
        ),
      ],
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && (passwordVisible != null && !passwordVisible),
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: Colors.white.withOpacity(0.9),
            size: 22,
          ),
          suffixIcon: isPassword && passwordVisible != null
              ? IconButton(
                  icon: Icon(
                    passwordVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withOpacity(0.7),
                    size: 22,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.withOpacity(0.7),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.08),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
  
  // Widget para crear botón animado
  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required int delay,
  }) {
    return Animate(
      effects: [
        FadeEffect(duration: 400.ms, delay: delay.ms),
        SlideEffect(
          begin: const Offset(0, 0.3),
          end: const Offset(0, 0),
          curve: Curves.easeOutQuad,
          duration: 500.ms,
          delay: delay.ms,
        ),
      ],
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF500A2),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFFF500A2).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Iniciando sesión...",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "INICIAR SESIÓN",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
  
  // Función para obtener el valor mínimo entre dos números
  double min(double a, double b) {
    return a < b ? a : b;
  }
}
