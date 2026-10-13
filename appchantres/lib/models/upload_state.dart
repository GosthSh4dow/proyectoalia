enum UploadPhase { idle, compressing, uploading, retrying, success, error }

class UploadState {
  final UploadPhase phase;
  final double progress;
  final String? message;
  final String? errorMessage;
  final int retryCount;
  final int maxRetries;

  const UploadState({
    required this.phase,
    this.progress = 0.0,
    this.message,
    this.errorMessage,
    this.retryCount = 0,
    this.maxRetries = 3,
  });

  factory UploadState.idle() => const UploadState(phase: UploadPhase.idle);

  factory UploadState.compressing({String? message}) =>
      UploadState(phase: UploadPhase.compressing, message: message ?? 'Comprimiendo imágenes...');

  factory UploadState.uploading({double progress = 0.0, String? message}) =>
      UploadState(phase: UploadPhase.uploading, progress: progress, message: message ?? 'Subiendo producto...');

  factory UploadState.retrying({required int attempt, int maxRetries = 3}) =>
      UploadState(
        phase: UploadPhase.retrying,
        retryCount: attempt,
        maxRetries: maxRetries,
        message: 'Reintentando... ($attempt/$maxRetries)',
      );

  factory UploadState.success({String? message}) =>
      UploadState(phase: UploadPhase.success, progress: 1.0, message: message ?? '¡Guardado!');

  factory UploadState.error({required String errorMessage, int retryCount = 0, int maxRetries = 3}) =>
      UploadState(
        phase: UploadPhase.error,
        errorMessage: errorMessage,
        retryCount: retryCount,
        maxRetries: maxRetries,
      );

  UploadState copyWith({
    UploadPhase? phase,
    double? progress,
    String? message,
    String? errorMessage,
    int? retryCount,
    int? maxRetries,
  }) {
    return UploadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  bool get isActive => phase == UploadPhase.compressing ||
      phase == UploadPhase.uploading ||
      phase == UploadPhase.retrying;

  bool get canRetry => phase == UploadPhase.error && retryCount < maxRetries;

  bool get isDone => phase == UploadPhase.success || phase == UploadPhase.error;
}
