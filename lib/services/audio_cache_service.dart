import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AudioCacheService {
  static const int maxCacheSizeBytes = 500 * 1024 * 1024; // 500MB

  static Future<File?> getCachedAudio(String url) async {
    try {
      final cacheDir = await _getCacheDir();
      final hash = md5.convert(utf8.encode(url)).toString();
      final file = File('${cacheDir.path}/$hash.m4a');

      if (await file.exists()) {
        // Update modified time for LRU
        await file.setLastModified(DateTime.now());
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<File?> downloadAndCacheAudio(String url) async {
    try {
      final cacheDir = await _getCacheDir();
      final hash = md5.convert(utf8.encode(url)).toString();
      final file = File('${cacheDir.path}/$hash.m4a');

      if (await file.exists()) {
        await file.setLastModified(DateTime.now());
        return file;
      }

      final dio = Dio();
      await dio.download(url, file.path);
      
      _enforceLRU(cacheDir);

      return file;
    } catch (e) {
      return null;
    }
  }

  static Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/moze_audio_cache');
    if (!(await cacheDir.exists())) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  static Future<void> _enforceLRU(Directory cacheDir) async {
    try {
      final files = await cacheDir.list().where((e) => e is File).cast<File>().toList();
      int totalSize = 0;
      final fileData = <File, int>{};
      final fileMods = <File, DateTime>{};

      for (var file in files) {
        final len = await file.length();
        totalSize += len;
        fileData[file] = len;
        fileMods[file] = await file.lastModified();
      }

      if (totalSize > maxCacheSizeBytes) {
        files.sort((a, b) => fileMods[a]!.compareTo(fileMods[b]!));
        
        for (var file in files) {
          totalSize -= fileData[file]!;
          await file.delete();
          if (totalSize <= maxCacheSizeBytes) {
            break;
          }
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}
