import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import 'settings_provider.dart';

/// Images provider state
class ImagesState {
  final List<ImageModel> images;
  final List<ImageModel> selectedImages;
  final bool isLoading;
  final String? errorMessage;

  const ImagesState({
    this.images = const [],
    this.selectedImages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ImagesState copyWith({
    List<ImageModel>? images,
    List<ImageModel>? selectedImages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ImagesState(
      images: images ?? this.images,
      selectedImages: selectedImages ?? this.selectedImages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get hasImages => images.isNotEmpty;
  bool get hasSelection => selectedImages.isNotEmpty;
  int get selectedCount => selectedImages.length;
}

/// Images provider implementation
class ImagesNotifier extends Notifier<ImagesState> {
  AppSettings? _settings;
  ImagingEdgeService? _service;
  bool _initialized = false;

  @override
  ImagesState build() {
    _ensureSettingsListener();
    return const ImagesState();
  }

  void _ensureSettingsListener() {
    if (_initialized) return;
    _initialized = true;

    final currentSettings = ref.read(settingsProvider);
    _applySettings(currentSettings);

    ref.listen<AppSettings>(
      settingsProvider,
      (previous, next) => _applySettings(next),
      fireImmediately: false,
    );
  }

  void _applySettings(AppSettings settings) {
    _settings = settings;
    _initializeService();
  }

  /// Initialize service with current settings
  void _initializeService() {
    final settings = _settings;
    if (settings == null) {
      _service = null;
      return;
    }

    _service = ImagingEdgeService(
      address: settings.cameraAddress,
      port: settings.cameraPort,
      debug: settings.debugMode,
    );
  }

  /// Browse images from camera
  Future<void> browseImages() async {
    _initializeService();
    if (_service == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _service!.startTransfer();

      final images = await _service!.browseImages();
      final updatedImages = await _updateDownloadStatus(images);

      state = state.copyWith(
        images: updatedImages,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Update download status for images
  Future<List<ImageModel>> _updateDownloadStatus(List<ImageModel> images) async {
    final settings = _settings;
    if (settings == null) {
      return images;
    }

    final outputDir = settings.outputDirectory.isNotEmpty 
        ? settings.outputDirectory
        : (await FileManager.getDefaultOutputDirectory()).path;

    final updatedImages = <ImageModel>[];
    
    for (final image in images) {
      final filename = FileManager.sanitizeFilename(image.title);
      final filepath = path.join(outputDir, filename);
      
      final isDownloaded = await FileManager.isFileDownloaded(filepath, image.size);
      final localPath = isDownloaded ? filepath : null;
      
      updatedImages.add(image.copyWith(
        isDownloaded: isDownloaded,
        localPath: localPath,
      ));
    }
    
    return updatedImages;
  }

  /// Select/deselect image
  void toggleImageSelection(ImageModel image) {
    final selected = List<ImageModel>.from(state.selectedImages);
    
    if (selected.contains(image)) {
      selected.remove(image);
    } else {
      selected.add(image);
    }
    
    state = state.copyWith(selectedImages: selected);
  }

  /// Select all images
  void selectAllImages() {
    state = state.copyWith(selectedImages: List.from(state.images));
  }

  /// Clear selection
  void clearSelection() {
    state = state.copyWith(selectedImages: []);
  }

  /// Select only undownloaded images
  void selectUndownloadedImages() {
    final undownloaded = state.images.where((img) => !img.isDownloaded).toList();
    state = state.copyWith(selectedImages: undownloaded);
  }

  /// Refresh images list
  Future<void> refreshImages() async {
    await browseImages();
  }

  /// Clear images list
  void clearImages() {
    state = state.copyWith(
      images: [],
      selectedImages: [],
      errorMessage: null,
    );
  }
}

/// Download provider state
class DownloadState {
  final DownloadProgress progress;
  final bool isDownloading;
  final List<ImageModel> downloadQueue;
  final String? errorMessage;

  const DownloadState({
    this.progress = const DownloadProgress(),
    this.isDownloading = false,
    this.downloadQueue = const [],
    this.errorMessage,
  });

  DownloadState copyWith({
    DownloadProgress? progress,
    bool? isDownloading,
    List<ImageModel>? downloadQueue,
    String? errorMessage,
  }) {
    return DownloadState(
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadQueue: downloadQueue ?? this.downloadQueue,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get canDownload => !isDownloading && downloadQueue.isNotEmpty;
  bool get hasError => errorMessage != null;
}

/// Download provider implementation
class DownloadNotifier extends Notifier<DownloadState> {
  AppSettings? _settings;
  ImagingEdgeService? _service;
  bool _isCancelled = false;
  bool _initialized = false;

  @override
  DownloadState build() {
    _ensureSettingsListener();
    return const DownloadState();
  }

  void _ensureSettingsListener() {
    if (_initialized) return;
    _initialized = true;

    final currentSettings = ref.read(settingsProvider);
    _applySettings(currentSettings);

    ref.listen<AppSettings>(
      settingsProvider,
      (previous, next) => _applySettings(next),
      fireImmediately: false,
    );
  }

  void _applySettings(AppSettings settings) {
    _settings = settings;
    _initializeService();
  }

  /// Initialize service with current settings
  void _initializeService() {
    final settings = _settings;
    if (settings == null) {
      _service = null;
      return;
    }

    _service = ImagingEdgeService(
      address: settings.cameraAddress,
      port: settings.cameraPort,
      debug: settings.debugMode,
    );
  }

  /// Start downloading images
  Future<void> startDownload(List<ImageModel> images) async {
    if (state.isDownloading || images.isEmpty) return;

    _initializeService();
    final settings = _settings;
    if (_service == null || settings == null) return;

    _isCancelled = false;
    
    state = state.copyWith(
      isDownloading: true,
      downloadQueue: images,
      errorMessage: null,
      progress: DownloadProgress(
        totalFiles: images.length,
        status: DownloadStatus.connecting,
        startTime: DateTime.now(),
      ),
    );

    try {
      // Ensure transfer is started
      await _service!.startTransfer();
      
      // Show notification if enabled
      if (settings.notificationsEnabled) {
        await NotificationService.showDownloadStartNotification(
          images.length,
          localeCode: settings.localeCode,
        );
      }

      // Get output directory
      final outputDir = settings.outputDirectory.isNotEmpty
          ? settings.outputDirectory
          : (await FileManager.getDefaultOutputDirectory()).path;

      await FileManager.ensureDirectoryExists(outputDir);

      // Calculate total size
      final totalSize = images.fold<int>(0, (sum, img) => sum + (img.size ?? 0));
      
      state = state.copyWith(
        progress: state.progress.copyWith(
          status: DownloadStatus.downloading,
          totalSize: totalSize,
        ),
      );

      int completedFiles = 0;
      int totalBytes = 0;

      // Download each image
      for (final image in images) {
        if (_isCancelled) break;

        final filename = FileManager.sanitizeFilename(image.title);
        final filepath = path.join(outputDir, filename);

        // Check if already downloaded
        if (await FileManager.isFileDownloaded(filepath, image.size)) {
          completedFiles++;
          totalBytes += image.size ?? 0;
          _updateProgress(completedFiles, totalBytes, filename);
          continue;
        }

        // Get best quality URL
        final url = image.bestQualityUrl;
        if (url == null) {
          logWarning('No URL available for image: ${image.title}');
          continue;
        }

        // Update progress for current file
        state = state.copyWith(
          progress: state.progress.copyWith(
            currentFileIndex: completedFiles + 1,
            currentFileName: filename,
            currentFileBytes: 0,
            currentFileSize: image.size ?? 0,
          ),
        );

        // Download file
        await _service!.downloadFile(
          url,
          filepath,
          expectedSize: image.size,
          onProgress: (downloaded, total) {
            if (!_isCancelled) {
              state = state.copyWith(
                progress: state.progress.copyWith(
                  currentFileBytes: downloaded,
                  totalBytes: totalBytes + downloaded,
                ),
              );

              // Update progress notification
              if (settings.notificationsEnabled) {
                NotificationService.showProgressNotification(
                  currentFile: completedFiles + 1,
                  totalFiles: images.length,
                  fileName: filename,
                  progress: total > 0 ? downloaded / total : 0.0,
                  localeCode: settings.localeCode,
                );
              }
            }
          },
        );

        if (!_isCancelled) {
          completedFiles++;
          totalBytes += image.size ?? 0;
          _updateProgress(completedFiles, totalBytes, filename);
        }
      }

      if (!_isCancelled) {
        // Download completed
        state = state.copyWith(
          progress: state.progress.copyWith(
            status: DownloadStatus.completed,
            endTime: DateTime.now(),
          ),
        );

        // Show completion notification
        if (settings.notificationsEnabled) {
          await NotificationService.cancelProgressNotification();
          await NotificationService.showDownloadCompletedNotification(
            completedFiles,
            outputDir,
            localeCode: settings.localeCode,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        progress: state.progress.copyWith(
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        ),
        errorMessage: e.toString(),
      );

      // Show error notification
      if (settings.notificationsEnabled) {
        await NotificationService.cancelProgressNotification();
        await NotificationService.showDownloadErrorNotification(
          e.toString(),
          localeCode: settings.localeCode,
        );
      }
    } finally {
      state = state.copyWith(isDownloading: false);
    }
  }

  /// Update progress state
  void _updateProgress(int completedFiles, int totalBytes, String currentFile) {
    state = state.copyWith(
      progress: state.progress.copyWith(
        currentFileIndex: completedFiles,
        currentFileName: currentFile,
        totalBytes: totalBytes,
      ),
    );
  }

  /// Cancel download
  void cancelDownload() {
    _isCancelled = true;
    state = state.copyWith(
      isDownloading: false,
      progress: state.progress.copyWith(
        status: DownloadStatus.idle,
      ),
    );

    // Cancel progress notification
    final settings = _settings;
    if (settings?.notificationsEnabled ?? false) {
      NotificationService.cancelProgressNotification();
    }
  }

  /// Reset download state
  void resetDownload() {
    state = const DownloadState();
  }
}

/// Images provider
final imagesProvider = NotifierProvider<ImagesNotifier, ImagesState>(
  ImagesNotifier.new,
);

/// Download provider
final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(
  DownloadNotifier.new,
);
