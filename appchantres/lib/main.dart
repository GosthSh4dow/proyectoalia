import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'providers/user_provider.dart';
import 'providers/local_connection_provider.dart';
import 'servicios/upload_notification_service.dart';
import 'servicios/foreground_upload_service.dart';
import 'paginas/reportes_screen.dart';
import 'paginas/sueldos_boletas_screen.dart';
import 'paginas/entrada_masiva_screen.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import './theme/custom_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Puerto de comunicación entre el isolate de fondo (foreground task) y la UI.
  // Debe llamarse antes de runApp.
  FlutterForegroundTask.initCommunicationPort();

  // Preparar los símbolos de fecha. Si falla, no debe bloquear el arranque.
  try {
    await initializeDateFormatting('es');
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => LocalConnectionProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Inicializar las notificaciones SIN bloquear el primer frame.
  // En release, esperar aquí antes de runApp() puede dejar la app
  // colgada en la pantalla blanca de arranque si el plugin no responde.
  final notificationService = UploadNotificationService();
  unawaited(notificationService.init());

  // Inicializar el servicio en primer plano para subidas en segundo plano.
  unawaited(ForegroundUploadService.instance.init());

  // Solicitar el permiso de notificaciones cuando la UI ya está en pantalla.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notificationService.requestPermission();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690), // Ajusta según tu diseño base
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: UploadNotificationService.navigatorKey,
          title: 'Channels',
          theme: AppTheme.lightTheme,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'), // Español
            Locale('en', 'US'), // Inglés
          ],
          locale: const Locale('es', 'ES'), // Configura el español como idioma por defecto
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: [
              const Breakpoint(start: 0, end: 450, name: MOBILE),
              const Breakpoint(start: 451, end: 800, name: TABLET),
              const Breakpoint(start: 801, end: 1920, name: DESKTOP),
              const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
            ],
          ),
          routes: {
            '/login': (context) => const LoginPage(),
            '/dashboard': (context) => const DashboardPage(),
            '/reportes': (context) => const ReportesScreen(),
            '/sueldosboletas': (context) => const SueldosBoletasScreen(),
            '/inventario-masivo': (context) => const EntradaMasivaScreen(),
          },
        );
      },
    );
  }
}

// Widget que verifica la autenticación para mostrar el login o el dashboard
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.checkAuth();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    final userProvider = Provider.of<UserProvider>(context);
    return userProvider.isAuthenticated ? const DashboardPage() : const LoginPage();
  }
}
