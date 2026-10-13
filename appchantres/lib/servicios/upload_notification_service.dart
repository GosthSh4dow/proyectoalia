import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../widgets/pending_upload_retry_screen.dart';

class UploadNotificationService {
  static final UploadNotificationService _instance = UploadNotificationService._();
  factory UploadNotificationService() => _instance;
  UploadNotificationService._();

  /// NavigatorKey global para navegar desde la notificaciÃ³n.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initFuture;
  // Throttle anti-spam: el progreso de Dio llega por cada chunk (decenas
  // de eventos por subida). Sin esto, en Linux/desktop se apilan tarjetas
  // "Subiendo... 18%/88%/91%" y en Android vibra/re-alerta sin parar.
  DateTime? _lastProgressAt;
  int _lastProgressPct = -1;

  /// Inicializar el canal de notificaciones.
  ///
  /// No debe bloquear el arranque de la app: si la plataforma no responde
  /// (o el permiso no se puede solicitar), se captura el error y la app
  /// continÃºa cargando.
  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _doInit();
    await _initFuture;
    _initFuture = null;
  }

  Future<void> _doInit() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        linux: linuxSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Cuando el usuario toca la notificaciÃ³n, abrir la pantalla de productos
          _handleNotificationTap(details);
        },
      );

      // Crear canal de notificaciones para Android
      await _createNotificationChannel();

      _initialized = true;
      debugPrint('UploadNotificationService: inicializado correctamente');
    } catch (e, st) {
      // No romper el arranque si falla la inicializaciÃ³n de notificaciones.
      debugPrint('Error inicializando notificaciones: $e $st');
      // Marcar como no inicializado para reintentar luego
      _initialized = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await init();
      // Pequeña espera para asegurar que el plugin esté listo en Android
      if (!_initialized) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_initialized) await init();
      }
    } catch (_) {
      // Silenciar, el show manejará el error
    }
  }

  /// Solicita permiso de notificaciones en Android 13+.
  ///
  /// Debe llamarse cuando la app ya estÃ¡ en pantalla (despuÃ©s del primer
  /// frame), nunca antes de `runApp()`, para evitar que la app se quede
  /// colgada en la pantalla de arranque en los builds de release.
  Future<void> requestPermission() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error solicitando permiso de notificaciones: $e');
    }
  }

  /// Canal de notificaciones para subida de productos
  Future<void> _createNotificationChannel() async {
    final channel = AndroidNotificationChannel(
      'upload_channel',
      'Subida de Productos',
      description: 'Progreso de subida de productos e imÃ¡genes',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Manejar toque en la notificaciÃ³n
  void _handleNotificationTap(NotificationResponse details) {
    // El payload contiene el id de la subida pendiente
    final payload = details.payload;
    if (payload != null && payload.startsWith('retry:')) {
      final pendingId = payload.substring(6);
      _openRetryScreen(pendingId);
    }
  }

  /// Abrir la pantalla de reintento para una subida pendiente
  void _openRetryScreen(String pendingId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    try {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PendingUploadRetryScreen(pendingId: pendingId),
        ),
      );
    } catch (e) {
      // No romper el flujo si no se pudo abrir la pantalla de reintento
    }
  }

  /// Mostrar notificaciÃ³n de progreso de compresiÃ³n
  Future<void> showCompressingNotification({int progress = 0, String? message}) async {
    try {
      if (!_shouldShowProgress(progress)) return;
      await _ensureInitialized();
      if (!_initialized) {
        debugPrint('showCompressingNotification: plugin no inicializado, omitiendo notificación');
        return;
      }
      await _plugin.show(
        1000, // ID unificado para todo el proceso
        'Procesando producto',
        message ?? 'Preparando...',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'upload_channel',
            'Subida de Productos',
            channelDescription: 'Progreso de subida de productos e imÃ¡genes',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: progress,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFFC026D3),
            silent: true,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('showCompressingNotification error (no crítico): $e $st');
      // No propagar, la subida debe continuar aunque falle la notificación
    }
  }

  /// Mostrar notificaciÃ³n de progreso de subida
  Future<void> showUploadingNotification({
    int progress = 0,
    String? message,
  }) async {
    try {
      if (!_shouldShowProgress(progress)) return;
      await _ensureInitialized();
      if (!_initialized) {
        debugPrint('showUploadingNotification: plugin no inicializado, omitiendo');
        return;
      }
      await _plugin.show(
        1000, // Mismo ID unificado
        'Subiendo producto',
        message ?? 'Enviando al servidor...',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'upload_channel',
            'Subida de Productos',
            channelDescription: 'Progreso de subida de productos e imÃ¡genes',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: progress,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF3B82F6),
            silent: true,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('showUploadingNotification error (no crítico): $e $st');
    }
  }

  /// Mostrar notificaciÃ³n de Ã©xito
  Future<void> showSuccessNotification({String? message}) async {
    try {
      await _ensureInitialized();
      if (!_initialized) return;
      await _plugin.show(
        1000, // Mismo ID unificado - reemplaza la de progreso
        '¡Producto guardado!',
        message ?? 'La imagen se subió correctamente',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'upload_channel',
            'Subida de Productos',
            channelDescription: 'Progreso de subida de productos e imágenes',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: false,
            icon: '@mipmap/launcher_icon',
            color: Color(0xFF22C55E),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('showSuccessNotification error: $e $st');
    }
  }

  /// Mostrar notificación de error con el nombre del producto.
  /// payload: `retry:<pendingId>` para navegar al reintento al tocar.
  Future<void> showErrorNotification({
    String? message,
    String? productName,
    String? retryPayload,
  }) async {
    try {
      await _ensureInitialized();
      if (!_initialized) {
        debugPrint('showErrorNotification: plugin no inicializado, error: $message');
        return;
      }
      await _plugin.show(
        1000, // Mismo ID unificado
        productName != null
            ? 'Error al subir: $productName'
            : 'Error al subir producto',
        message ?? (retryPayload != null ? 'Toca para reintentar' : 'Toca para ver el error'),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'upload_channel',
            'Subida de Productos',
            channelDescription: 'Progreso de subida de productos e imágenes',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false, // <- Se puede descartar con swipe
            autoCancel: true, // <- Se cancela al tocar
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFFEF4444),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: retryPayload,
      );
    } catch (e, st) {
      debugPrint('showErrorNotification error: $e $st');
    }
  }

  /// Throttle: muestra si es 0%/100%, si avanzó >=5% o si pasó >=1s.
  /// Sin esto cada chunk de red genera una tarjeta de notificación.
  bool _shouldShowProgress(int progress) {
    final now = DateTime.now();
    if (progress <= 0 || progress >= 100) {
      _lastProgressPct = progress;
      _lastProgressAt = now;
      return true;
    }
    final pctDelta = (progress - _lastProgressPct).abs();
    final timeDelta = _lastProgressAt == null
        ? const Duration(days: 1)
        : now.difference(_lastProgressAt!);
    if (pctDelta >= 5 || timeDelta.inMilliseconds >= 1000) {
      _lastProgressPct = progress;
      _lastProgressAt = now;
      return true;
    }
    return false;
  }

  /// Cancelar todas las notificaciones de upload
  Future<void> cancelAll() async {
    try {
      // Resetear throttle para que la próxima subida notifique desde 0%.
      _lastProgressPct = -1;
      _lastProgressAt = null;
      await _ensureInitialized();
      if (!_initialized) return;
      await _plugin.cancel(1000);
    } catch (e, st) {
      debugPrint('cancelAll error: $e $st');
    }
  }
}

