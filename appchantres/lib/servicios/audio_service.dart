import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../api.dart';
import '../models/product_form_data.dart';
import 'api_service.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final Dio _dio = ApiService().dio;
  String? _currentPath;
  Timer? _durationTimer;
  int _recordingDuration = 0;

  Future<bool> get isRecording async => await _recorder.isRecording();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording({
    void Function(int seconds)? onDurationUpdate,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permiso de micrófono no concedido');
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    _currentPath = '${dir.path}/$fileName';
    _recordingDuration = 0;

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _currentPath!,
    );

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      onDurationUpdate?.call(_recordingDuration);
    });
  }

  Future<void> cancelRecording() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _recordingDuration = 0;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    if (_currentPath != null) {
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentPath = null;
    }
  }

  Future<AudioResult> stopRecordingAndSend({
    String modelo = 'glm-5.1',
    String? contexto,
  }) async {
    _durationTimer?.cancel();
    _durationTimer = null;

    final duration = _recordingDuration;
    _recordingDuration = 0;

    if (duration < 1) {
      throw Exception('Grabación muy corta');
    }

    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw Exception('Error al detener grabación');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Archivo de audio no encontrado');
    }

    final fileSize = await file.length();
    final result = await _sendAudioToBackend(
      file: file,
      modelo: modelo,
      contexto: contexto,
    );

    try {
      await file.delete();
    } catch (_) {}

    _currentPath = null;
    return AudioResult(
      durationSeconds: duration,
      filePath: path,
      fileSizeBytes: fileSize,
      productData: result,
    );
  }

  Future<ProductFormData> _sendAudioToBackend({
    required File file,
    required String modelo,
    String? contexto,
  }) async {
    final formData = FormData();
    formData.fields.addAll([
      MapEntry('modelo', modelo),
    ]);
    if (contexto != null) {
      formData.fields.add(MapEntry('contexto', contexto));
    }
    formData.files.add(MapEntry(
      'audio',
      await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    ));

    final response = await _dio.post(
      '$BASE_URL/ai/interpretar-audio',
      data: formData,
      options: Options(
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = Map<String, dynamic>.from(response.data['data']);
      return ProductFormData.fromJson(data);
    } else {
      throw Exception(response.data['error'] ?? 'Error al procesar audio');
    }
  }

  void dispose() {
    _durationTimer?.cancel();
  }
}

class AudioResult {
  final int durationSeconds;
  final String filePath;
  final int fileSizeBytes;
  final ProductFormData productData;

  AudioResult({
    required this.durationSeconds,
    required this.filePath,
    required this.fileSizeBytes,
    required this.productData,
  });

  String get formattedDuration {
    final min = durationSeconds ~/ 60;
    final sec = durationSeconds % 60;
    return min > 0 ? '$min:${sec.toString().padLeft(2, '0')}' : '0:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1048576) return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(fileSizeBytes / 1048576).toStringAsFixed(1)}MB';
  }
}
