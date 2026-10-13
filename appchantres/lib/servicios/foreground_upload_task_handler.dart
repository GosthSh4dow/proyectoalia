import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'pending_upload_service.dart';
import 'upload_notification_service.dart';

/// Callback de entrada del isolate de fondo.
///
/// Debe ser una función de nivel superior con `vm:entry-point`. Cuando se
/// inicia el servicio en primer plano, Android ejecuta esta función en un
/// isolate separado; aquí se registra el [TaskHandler].
@pragma('vm:entry-point')
void foregroundUploadStartCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundUploadTaskHandler());
}

/// Procesa la cola de subidas pendientes desde el isolate de fondo.
///
/// Ejecuta cada subida pendiente, actualiza la notificación del servicio en
/// primer plano con el progreso y notifica al isolate principal los resultados
/// vía [FlutterForegroundTask.sendDataToMain] para actualizar la lista de
/// productos en la UI.
class ForegroundUploadTaskHandler extends TaskHandler {
  bool _processing = false;
  // Id de la subida que debe procesarse a continuación (encadenado si el
  // usuario registra varios productos seguidos).
  String? _pendingOnlyId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[ForegroundUploadTaskHandler] onStart (starter: ${starter.name}) ts=$timestamp');
    await _restoreSession();
    // Procesar SOLO la subida que disparó este arranque (guardada en prefs),
    // para no re-subir productos pendientes antiguos.
    final prefs = await SharedPreferences.getInstance();
    final onlyId = prefs.getString('foreground_pending_process');
    debugPrint('[ForegroundUploadTaskHandler] onStart onlyId=$onlyId');
    await _processQueue(onlyId: onlyId);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    debugPrint('[ForegroundUploadTaskHandler] onRepeatEvent $timestamp no-op');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[ForegroundUploadTaskHandler] onDestroy isTimeout=$isTimeout ts=$timestamp');
  }

  @override
  void onReceiveData(Object data) {
    // El isolate principal despierta al handler cuando se agrega una subida
    // pendiente y el servicio ya estaba corriendo. Solo la indicada.
    debugPrint('[ForegroundUploadTaskHandler] onReceiveData: $data');
    if (data is String && data.startsWith('process')) {
      String? id;
      if (data.length > 'process:'.length) {
        id = data.substring('process:'.length);
      }
      if (id != null && id.isNotEmpty) {
        final pid = id;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('foreground_pending_process', pid);
        }).catchError((e) {
          debugPrint('[ForegroundUploadTaskHandler] onReceiveData setString error: $e');
        });
        _processQueue(onlyId: id);
      } else {
        debugPrint('[ForegroundUploadTaskHandler] onReceiveData process sin id, ignora');
      }
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('[ForegroundUploadTaskHandler] onNotificationButtonPressed $id');
  }

  @override
  void onNotificationPressed() {
    debugPrint('[ForegroundUploadTaskHandler] onNotificationPressed');
  }

  @override
  void onNotificationDismissed() {
    debugPrint('[ForegroundUploadTaskHandler] onNotificationDismissed');
  }

  /// Carga el token de sesión desde SharedPreferences.
  ///
  /// En el isolate de fondo no se ejecuta el flujo de login de la UI, así que
  /// `ApiService` parte sin token y las peticiones fallarían con 401.
  /// Verifica que los tokens se carguen correctamente y loguea estado.
  Future<void> _restoreSession() async {
    try {
      debugPrint('[ForegroundUploadTaskHandler] _restoreSession inicio');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? prefs.getString('token');
      final refreshToken = prefs.getString('refreshToken');
      if (token == null || token.isEmpty) {
        debugPrint('[ForegroundUploadTaskHandler] _restoreSession WARN: token vacío (authToken/token null) -> subidas fallarán 401');
      } else {
        debugPrint('[ForegroundUploadTaskHandler] _restoreSession token len=${token.length} refresh=${refreshToken != null && refreshToken.isNotEmpty}');
      }
      ApiService().updateTokens(token, refreshToken);
      debugPrint('[ForegroundUploadTaskHandler] _restoreSession ApiService.updateTokens ok');
    } catch (e, st) {
      debugPrint('[ForegroundUploadTaskHandler] _restoreSession error: $e $st');
    }
  }

  Future<void> _processQueue({String? onlyId}) async {
    // Si ya hay una cola corriendo, encolar este id para procesarlo al terminar.
    if (_processing) {
      debugPrint('[ForegroundUploadTaskHandler] _processQueue ya procesando, encola onlyId=$onlyId pending=$_pendingOnlyId');
      if (onlyId != null) _pendingOnlyId = onlyId;
      return;
    }
    _processing = true;
    debugPrint('[ForegroundUploadTaskHandler] _processQueue inicio (onlyId=$onlyId)');

    final pendingService = PendingUploadService();
    final notifService = UploadNotificationService();
    await notifService.init();

    try {
      final attempted = <String>{}; // ids ya intentados en ESTA corrida -> evita reintentos infinitos
      var successCount = 0;
      int loopGuard = 0;
      const maxLoops = 10; // salvaguarda anti-bucle infinito

      while (true) {
        if (loopGuard++ > maxLoops) {
          debugPrint('[ForegroundUploadTaskHandler] _processQueue loopGuard $maxLoops alcanzado, break');
          break;
        }
        final target = onlyId ?? _pendingOnlyId;
        _pendingOnlyId = null;
        onlyId = null; // se consume; las iteraciones siguientes usan _pendingOnlyId

        final all = await pendingService.getAll();
        var next = all.where((u) => !attempted.contains(u.id)).toList()
          // Procesar primero la subida más reciente (id = timestamp).
          ..sort((a, b) => b.id.compareTo(a.id));
        // IMPORTANTE: solo la subida indicada (la que se acaba de registrar),
        // NUNCA reprocesar pendientes antiguos.
        if (target != null) {
          next = next.where((u) => u.id == target).toList();
        }
        if (next.isEmpty) {
          debugPrint('[ForegroundUploadTaskHandler] _processQueue next vacío target=$target attempted=$attempted break');
          break;
        }

        debugPrint('[ForegroundUploadTaskHandler] _processQueue iteración $loopGuard target=$target next=${next.map((e)=>e.id).toList()}');

        for (final upload in next) {
          if (attempted.contains(upload.id)) {
            debugPrint('[ForegroundUploadTaskHandler] skip ya intentado ${upload.id}');
            continue;
          }
          attempted.add(upload.id);
          debugPrint('[ForegroundUploadTaskHandler] subiendo "${upload.nombre}" id=${upload.id} modo=${upload.modoSubida} imgs=${upload.imagenPaths.length}');

          await FlutterForegroundTask.updateService(
            notificationTitle: 'Subiendo producto',
            notificationText: '${upload.nombre}...',
          );

          // Sin imágenes el body es JSON pequeño y termina rápido: no
          // spamear con porcentajes, basta la notificación única de arriba.
          final hasImages = upload.imagenPaths.isNotEmpty;
          var lastPct = -1;
          var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
          final result = await pendingService.enviar(
            upload,
            onProgress: (sent, total) {
              if (total > 0 && hasImages) {
                final pct = (sent / total * 100).toInt();
                final now = DateTime.now();
                if (pct >= 100 ||
                    (pct - lastPct).abs() >= 5 ||
                    now.difference(lastUpdate).inMilliseconds >= 1000) {
                  lastPct = pct;
                  lastUpdate = now;
                  FlutterForegroundTask.updateService(
                    notificationTitle: 'Subiendo producto',
                    notificationText: '${upload.nombre}: $pct%',
                  );
                }
              }
            },
          );

          if (result.errorMsg == null) {
            successCount++;
            debugPrint('[ForegroundUploadTaskHandler] "${upload.nombre}" OK id=${upload.id}');
            await pendingService.remove(upload.id);
            // Limpiar pref si era el target
            if (target == upload.id) {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('foreground_pending_process');
              } catch (_) {}
            }
            FlutterForegroundTask.sendDataToMain(<String, dynamic>{
              'type': 'product_uploaded',
              'uploadId': upload.id,
              'nombre': upload.nombre,
              'data': result.data,
            });
          } else {
            debugPrint('[ForegroundUploadTaskHandler] "${upload.nombre}" FALLO id=${upload.id}: ${result.errorMsg}');
            upload.lastError = result.errorMsg;
            // Guardar error pero NO reencolar automáticamente en esta misma corrida
            // attempted ya lo marca, así no hay bucle infinito.
            await pendingService.save(upload);
            await notifService.showErrorNotification(
              message: result.errorMsg,
              productName: upload.nombre,
              retryPayload: 'retry:${upload.id}',
            );
            FlutterForegroundTask.sendDataToMain(<String, dynamic>{
              'type': 'upload_failed',
              'uploadId': upload.id,
              'nombre': upload.nombre,
              'error': result.errorMsg,
            });
          }
        }

        // Si llegó un nuevo pedido mientras procesábamos, repetir el ciclo.
        if (_pendingOnlyId == null) {
          debugPrint('[ForegroundUploadTaskHandler] _processQueue sin pendingOnlyId, break');
          break;
        }
        debugPrint('[ForegroundUploadTaskHandler] _processQueue nuevo pendingOnlyId=$_pendingOnlyId, continúa loop');
      }

      if (successCount > 0) {
        await notifService.showSuccessNotification(
          message: successCount == 1
              ? 'Producto subido correctamente'
              : '$successCount productos subidos correctamente',
        );
      }

      debugPrint('[ForegroundUploadTaskHandler] cola procesada success=$successCount, deteniendo servicio');
      await FlutterForegroundTask.stopService();
    } catch (e, st) {
      debugPrint('[ForegroundUploadTaskHandler] error procesando cola: $e $st');
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
    } finally {
      _processing = false;
      debugPrint('[ForegroundUploadTaskHandler] _processQueue finally processing=false');
    }
  }
}
