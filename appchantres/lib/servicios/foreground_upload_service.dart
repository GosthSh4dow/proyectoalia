import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_upload.dart';
import 'pending_upload_service.dart';
import 'foreground_upload_task_handler.dart';

/// Gestiona el servicio en primer plano que ejecuta las subidas de productos
/// en un isolate de fondo.
///
/// - Inicializa el plugin (debe llamarse una vez al arrancar la app).
/// - Arranca el servicio cuando hay una subida pendiente.
/// - Despierta el handler si el servicio ya estaba corriendo.
/// - Reenvía al isolate principal los resultados enviados por el TaskHandler.
class ForegroundUploadService {
  static final ForegroundUploadService instance = ForegroundUploadService._();
  ForegroundUploadService._();

  bool _initialized = false;
  final List<DataCallback> _listeners = [];

  /// Inicializa el plugin con las opciones de notificación y del servicio.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'upload_service',
        channelName: 'Subida de productos',
        channelDescription: 'Notificación de subida de productos en segundo plano',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No se necesita onRepeatEvent: el handler procesa la cola una sola vez.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        // Que la subida continúe aunque el usuario quite la app de recientes.
        stopWithTask: false,
      ),
    );

    FlutterForegroundTask.addTaskDataCallback(_forwardTaskData);
  }

  /// Limpia UNA sola vez los pendientes antiguos (productos ya registrados)
  /// para que no reaparezcan al subir uno nuevo. Se llama al INICIO de onSave,
  /// antes de comprimir/persistir el producto actual (así jamás borra su imagen).
  Future<void> clearLegacyPendingOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pending_cleared_v1') == true) return;
      await PendingUploadService().clearAll();
      await prefs.setBool('pending_cleared_v1', true);
    } catch (_) {}
  }

  /// Reenvía a la UI los datos recibidos del TaskHandler.
  void _forwardTaskData(Object data) {
    for (final callback in List.of(_listeners)) {
      callback(data);
    }
  }

  /// Registra un callback que recibe los datos enviados por el TaskHandler.
  void addTaskDataListener(DataCallback callback) {
    if (!_listeners.contains(callback)) {
      _listeners.add(callback);
    }
  }

  /// Elimina un callback previamente registrado.
  void removeTaskDataListener(DataCallback callback) {
    _listeners.remove(callback);
  }

  /// Arranca la subida en segundo plano para la cola de pendientes.
  ///
  /// La subida en sí la ejecuta [ForegroundUploadTaskHandler] en el isolate de
  /// fondo. Retorna `true` si el servicio quedó a cargo de la subida.
  Future<bool> startUpload(PendingUpload upload) async {
    try {
      if (!_initialized) await init();
      await _ensureNotificationPermission();
      debugPrint('[ForegroundUploadService] startUpload("${upload.nombre}")');

      // Registrar SOLO esta subida como la que debe procesar el handler,
      // para no re-subir pendientes antiguos al registrar un producto nuevo.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('foreground_pending_process', upload.id);

      if (await FlutterForegroundTask.isRunningService) {
        // El servicio ya está corriendo: actualizar la notificación y despertar
        // al handler para que procese ÚNICAMENTE esta nueva subida pendiente.
        debugPrint('[ForegroundUploadService] servicio ya corriendo, despertando handler');
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Subiendo producto',
          notificationText: '${upload.nombre}...',
        );
        FlutterForegroundTask.sendDataToTask('process:${upload.id}');
        return true;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: 'Subiendo producto',
        notificationText: '${upload.nombre}...',
        callback: foregroundUploadStartCallback,
      );

      final ok = result is ServiceRequestSuccess;
      debugPrint('[ForegroundUploadService] startService result: '
          '${ok ? 'OK' : (result as ServiceRequestFailure).error}');
      return ok;
    } catch (e) {
      debugPrint('[ForegroundUploadService] error en startUpload: $e');
      return false;
    }
  }

  /// Detiene el servicio si está corriendo.
  Future<void> stopAll() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }

  Future<void> _ensureNotificationPermission() async {
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}
  }
}
