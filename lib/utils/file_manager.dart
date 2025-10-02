import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileManager {
  /// Get the default output directory for downloaded images
  static Future<Directory> getDefaultOutputDirectory() async {
    try {
      // Prefer the user's Downloads directory
      final downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        final outputDir = Directory(path.join(downloadsDirectory.path, 'ImagingEdgeNext'));

        if (!await outputDir.exists()) {
          await outputDir.create(recursive: true);
        }

        return outputDir;
      }
    } catch (_) {
      // Ignore errors and try manual fallbacks
    }

    // Fallback to a manually resolved Downloads directory if available
    final homeDirectory = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];

    if (homeDirectory != null) {
      final downloadsPath = Platform.isWindows
          ? path.join(homeDirectory, 'Downloads')
          : path.join(homeDirectory, 'Downloads');
      final outputDir = Directory(path.join(downloadsPath, 'ImagingEdgeNext'));

      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      return outputDir;
    }

    // Final fallback to the application documents directory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final outputDir = Directory(path.join(documentsDirectory.path, 'ImagingEdgeNextDownloads'));

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir;
  }

  /// Check if a file exists and has the expected size
  static Future<bool> isFileDownloaded(String filePath, int? expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      if (expectedSize != null) {
        final stat = await file.stat();
        return stat.size == expectedSize;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file size
  static Future<int?> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      return null;
    }
  }

  /// Create directory if it doesn't exist
  static Future<void> ensureDirectoryExists(String dirPath) async {
    try {
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      throw FileManagerException('Failed to create directory: $dirPath - $e');
    }
  }

  /// Generate safe filename by removing invalid characters
  static String sanitizeFilename(String filename) {
    // Remove or replace invalid characters for file systems
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    return filename.replaceAll(invalidChars, '_').trim();
  }

  /// Get unique filename by adding number suffix if file exists
  static Future<String> getUniqueFilename(String filePath) async {
    String finalPath = filePath;
    int counter = 1;
    
    while (await File(finalPath).exists()) {
      final dir = path.dirname(filePath);
      final name = path.basenameWithoutExtension(filePath);
      final ext = path.extension(filePath);
      
      finalPath = path.join(dir, '${name}_$counter$ext');
      counter++;
    }
    
    return finalPath;
  }

  /// Delete file if it exists
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get directory size in bytes
  static Future<int> getDirectorySize(Directory directory) async {
    int size = 0;
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            size += stat.size;
          }
        }
      }
    } catch (e) {
      // Ignore errors and return current size
    }
    return size;
  }

  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get file extension from URL or filename
  static String getFileExtension(String urlOrFilename) {
    // Remove query parameters if it's a URL
    final cleanUrl = urlOrFilename.split('?').first;
    return path.extension(cleanUrl).toLowerCase();
  }

  /// Extract filename from URL
  static String getFilenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    } catch (e) {
      // Fallback to simple extraction
    }
    
    // Simple fallback
    final parts = url.split('/');
    if (parts.isNotEmpty) {
      return parts.last.split('?').first; // Remove query parameters
    }
    
    return 'unknown_file';
  }
}

class FileManagerException implements Exception {
  final String message;
  const FileManagerException(this.message);
  
  @override
  String toString() => 'FileManagerException: $message';
}
