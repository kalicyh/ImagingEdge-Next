enum DownloadStatus {
  idle,
  connecting,
  browsing,
  downloading,
  paused,
  completed,
  error,
}

class DownloadProgress {
  final int currentFileIndex;
  final int totalFiles;
  final String currentFileName;
  final int currentFileBytes;
  final int currentFileSize;
  final int totalBytes;
  final int totalSize;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime? startTime;
  final DateTime? endTime;

  const DownloadProgress({
    this.currentFileIndex = 0,
    this.totalFiles = 0,
    this.currentFileName = '',
    this.currentFileBytes = 0,
    this.currentFileSize = 0,
    this.totalBytes = 0,
    this.totalSize = 0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
    this.startTime,
    this.endTime,
  });

  DownloadProgress copyWith({
    int? currentFileIndex,
    int? totalFiles,
    String? currentFileName,
    int? currentFileBytes,
    int? currentFileSize,
    int? totalBytes,
    int? totalSize,
    DownloadStatus? status,
    String? errorMessage,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return DownloadProgress(
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFileName: currentFileName ?? this.currentFileName,
      currentFileBytes: currentFileBytes ?? this.currentFileBytes,
      currentFileSize: currentFileSize ?? this.currentFileSize,
      totalBytes: totalBytes ?? this.totalBytes,
      totalSize: totalSize ?? this.totalSize,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// Current file progress percentage (0.0 to 1.0)
  double get currentFileProgress {
    if (currentFileSize == 0) return 0.0;
    return currentFileBytes / currentFileSize;
  }

  /// Overall progress percentage (0.0 to 1.0)
  double get overallProgress {
    if (totalSize == 0) return 0.0;
    return totalBytes / totalSize;
  }

  /// Files completed percentage (0.0 to 1.0)
  double get filesProgress {
    if (totalFiles == 0) return 0.0;
    return currentFileIndex / totalFiles;
  }

  /// Estimated time remaining in seconds
  Duration? get estimatedTimeRemaining {
    if (startTime == null || totalBytes == 0 || totalSize == 0) return null;
    
    final elapsed = DateTime.now().difference(startTime!);
    final progress = overallProgress;
    
    if (progress == 0) return null;
    
    final totalEstimated = elapsed.inSeconds / progress;
    final remaining = totalEstimated - elapsed.inSeconds;
    
    return Duration(seconds: remaining.round());
  }

  /// Download speed in bytes per second
  double? get downloadSpeed {
    if (startTime == null || totalBytes == 0) return null;
    
    final elapsed = DateTime.now().difference(startTime!);
    if (elapsed.inSeconds == 0) return null;
    
    return totalBytes / elapsed.inSeconds;
  }

  @override
  String toString() {
    return 'DownloadProgress(status: $status, currentFile: $currentFileIndex/$totalFiles, progress: ${(overallProgress * 100).toStringAsFixed(1)}%)';
  }
}