import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

class CacheService {
  /// Calculates total size of temporary and media cache files in bytes
  static Future<int> getTotalCacheSizeBytes() async {
    int totalBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        totalBytes += await _getDirSize(tempDir);
      }
    } catch (_) {}
    return totalBytes;
  }

  /// Helper to recursively calculate directory size
  static Future<int> _getDirSize(Directory dir) async {
    int bytes = 0;
    try {
      final entities = await dir.list(recursive: true, followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          bytes += await entity.length();
        }
      }
    } catch (_) {}
    return bytes;
  }

  /// Formatted string like "12.4 MB" or "320 KB"
  static Future<String> getFormattedCacheSize() async {
    final bytes = await getTotalCacheSizeBytes();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Clears media cache, temporary files, video compression cache and Flutter image memory cache
  static Future<void> clearAllCache() async {
    try {
      // Clear Flutter memory image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear video_compress cache
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}

      // Clear temp directory contents safely
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = await tempDir.list(recursive: false).toList();
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {
            // Some file might be open/locked by OS, ignore
          }
        }
      }
    } catch (_) {}
  }
}

