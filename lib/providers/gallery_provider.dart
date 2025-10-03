import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../utils/file_manager.dart';
import 'settings_provider.dart';

class GalleryItem {
  const GalleryItem({
    required this.filePath,
    required this.size,
    required this.modified,
  });

  final String filePath;
  final int size;
  final DateTime modified;

  String get displayName => path.basename(filePath);
}

class GalleryState {
  const GalleryState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.lastUpdated,
  });

  final List<GalleryItem> items;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastUpdated;

  GalleryState copyWith({
    List<GalleryItem>? items,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return GalleryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class GalleryNotifier extends StateNotifier<GalleryState> {
  GalleryNotifier(this._settings) : super(const GalleryState());

  AppSettings _settings;

  static const Set<String> _supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.gif',
    '.bmp',
    '.webp',
  };

  Future<void> loadImages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final directoryPath = _settings.outputDirectory.isNotEmpty
          ? _settings.outputDirectory
          : (await FileManager.getDefaultOutputDirectory()).path;

      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        state = state.copyWith(
          items: const [],
          isLoading: false,
          errorMessage: null,
          lastUpdated: DateTime.now(),
        );
        return;
      }

      final items = <GalleryItem>[];
      await for (final entity in directory.list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;

        final extension = path.extension(entity.path).toLowerCase();
        if (!_supportedExtensions.contains(extension)) {
          continue;
        }

        try {
          final stat = await entity.stat();
          items.add(
            GalleryItem(
              filePath: entity.path,
              size: stat.size,
              modified: stat.modified,
            ),
          );
        } catch (_) {
          // Ignore files that cannot be read.
        }
      }

      items.sort((a, b) => b.modified.compareTo(a.modified));

      state = state.copyWith(
        items: items,
        isLoading: false,
        errorMessage: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    loadImages();
  }
}

final galleryProvider = StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  final settings = ref.read(settingsProvider);
  final notifier = GalleryNotifier(settings);

  ref.listen(settingsProvider, (previous, next) {
    if (previous == next) return;
    notifier.updateSettings(next);
  });

  return notifier;
});
