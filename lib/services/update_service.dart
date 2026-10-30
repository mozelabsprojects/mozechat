import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';

class UpdateInfo {
  final String latestVersion;
  final int? latestVersionCode;
  final String currentVersion;
  final String changelog;
  final String downloadUrl;
  final bool isUpdateAvailable;
  final bool forceUpdate;

  UpdateInfo({
    required this.latestVersion,
    this.latestVersionCode,
    required this.currentVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.isUpdateAvailable,
    this.forceUpdate = false,
  });
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _githubRepo = "mozelabsprojects/mozechat";
  static const String _releasesApiUrl = "https://api.github.com/repos/$_githubRepo/releases/latest";
  static const String _rawVersionUrl = "https://raw.githubusercontent.com/$_githubRepo/main/version.json";

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  bool _isChecking = false;
  bool _isDownloading = false;

  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;

  /// Semver & Build Number karşılaştırıcısı (Örn: "0.1.1" > "0.1.0" veya 2 > 1)
  static bool isNewerVersion(String latest, String current, {int? latestCode, int? currentCode}) {
    if (latestCode != null && currentCode != null && latestCode > currentCode) {
      return true;
    }
    try {
      final cleanLatest = latest.replaceAll(RegExp(r'^[vV]'), '').trim();
      final cleanCurrent = current.replaceAll(RegExp(r'^[vV]'), '').trim();

      final lBuild = cleanLatest.contains('+') ? int.tryParse(cleanLatest.split('+')[1]) ?? 0 : 0;
      final cBuild = cleanCurrent.contains('+') ? int.tryParse(cleanCurrent.split('+')[1]) ?? 0 : 0;

      final lParts = cleanLatest.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return lBuild > cBuild;
    } catch (_) {
      return false;
    }
  }

  /// GitHub veya raw version.json üzerinden güncellemeleri denetler
  Future<UpdateInfo?> checkForUpdate({bool showToastIfUpToDate = false, BuildContext? context}) async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      String latestVersion = currentVersion;
      int? latestVersionCode;
      String changelog = "Küçük performans iyileştirmeleri ve hata düzeltmeleri.";
      String downloadUrl = "https://github.com/$_githubRepo/releases/latest";
      bool forceUpdate = false;

      // 1. Önce GitHub Releases API'yi dene
      bool fetchedFromGithub = false;
      try {
        final response = await _dio.get(
          _releasesApiUrl,
          options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final tagName = (data['tag_name'] as String? ?? '').replaceAll(RegExp(r'^[vV]'), '');
          if (tagName.isNotEmpty) {
            latestVersion = tagName;
            changelog = data['body'] as String? ?? changelog;

            final assets = data['assets'] as List<dynamic>? ?? [];
            for (var asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
                break;
              }
            }
            fetchedFromGithub = true;
          }
        }
      } catch (e) {
        debugPrint("GitHub Releases API check error (falling back to version.json): $e");
      }

      // 2. Eğer GitHub Release henüz yayınlanmadıysa raw version.json'ı dene
      if (!fetchedFromGithub) {
        try {
          final response = await _dio.get(
            _rawVersionUrl,
            options: Options(headers: {'Cache-Control': 'no-cache'}),
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data is Map ? response.data : Map<String, dynamic>.from(response.data);
            latestVersion = data['version'] as String? ?? currentVersion;
            latestVersionCode = data['versionCode'] as int?;
            changelog = data['changelog'] as String? ?? changelog;
            downloadUrl = data['downloadUrl'] as String? ?? downloadUrl;
            forceUpdate = data['forceUpdate'] as bool? ?? false;
          }
        } catch (e) {
          debugPrint("Raw version.json check error: $e");
        }
      }

      final currentCode = int.tryParse(packageInfo.buildNumber);
      final hasUpdate = isNewerVersion(
        latestVersion,
        currentVersion,
        latestCode: latestVersionCode,
        currentCode: currentCode,
      );

      final info = UpdateInfo(
        latestVersion: latestVersion,
        latestVersionCode: latestVersionCode,
        currentVersion: currentVersion,
        changelog: changelog,
        downloadUrl: downloadUrl,
        isUpdateAvailable: hasUpdate,
        forceUpdate: forceUpdate,
      );

      if (hasUpdate) {
        // Sistem bildirimi gönder
        NotificationService.showMessageNotification(
          title: "🚀 Yeni Mozechat Güncellemesi! (v$latestVersion)",
          body: "Yeni sürüm hazır. Uygulama içinden doğrudan yükleyebilirsiniz.",
          payload: "app_update",
        );

        if (context != null && context.mounted) {
          showUpdateDialog(context, info);
        }
      } else if (showToastIfUpToDate && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sistem güncel: Mozechat v$currentVersion"),
            backgroundColor: const Color(0xFF159D87),
          ),
        );
      }

      return info;
    } catch (e) {
      debugPrint("Update check general error: $e");
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// APK dosyasını indirir ve Android yerel paket yükleyicisini açar
  Future<void> downloadAndInstallApk(
    BuildContext context,
    String downloadUrl, {
    required Function(double progress, String eta) onProgress,
    required Function(String error) onError,
  }) async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      if (Platform.isAndroid) {
        // Android 8+ için bilinmeyen kaynaklardan yükleme izni kontrolü
        final installPermission = await Permission.requestInstallPackages.status;
        if (!installPermission.isGranted) {
          await Permission.requestInstallPackages.request();
        }
      }

      final tempDir = await getTemporaryDirectory();
      final apkPath = "${tempDir.path}/mozechat_update.apk";
      final apkFile = File(apkPath);
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final stopwatch = Stopwatch()..start();

      await _dio.download(
        downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final elapsed = stopwatch.elapsed.inSeconds;
            String eta = "";
            if (elapsed > 0 && received > 0) {
              final bytesPerSec = received / elapsed;
              final remainingSec = ((total - received) / bytesPerSec).round();
              eta = "${remainingSec}s";
            }
            onProgress(progress, eta);
          }
        },
      );

      // İndirme bitti -> Kurulumu tetikle
      if (Platform.isAndroid) {
        final result = await OpenFilex.open(
          apkPath,
          type: "application/vnd.android.package-archive",
        );
        debugPrint("OpenFilex install result: ${result.message}");
        if (result.type != ResultType.done) {
          // Fallback olarak tarayıcıdan indirmeyi aç
          final uri = Uri.parse(downloadUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("APK download error: $e");
      onError(e.toString());
      // Fallback
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      _isDownloading = false;
    }
  }

  /// Uygulama açılışında arka planda güncelleme kontrolü başlatır
  void checkUpdateOnStartup(BuildContext context) {
    Future.delayed(const Duration(seconds: 4), () {
      if (context.mounted) {
        checkForUpdate(context: context);
      }
    });
  }

  /// Cyberpunk stilli Güncelleme Dialog'u
  void showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) {
        return _UpdateDialogWidget(info: info);
      },
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialogWidget({required this.info});

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _downloading = false;
  double _progress = 0.0;
  String _eta = "";
  String? _errorMessage;

  void _startDownload() {
    setState(() {
      _downloading = true;
      _errorMessage = null;
    });

    UpdateService().downloadAndInstallApk(
      context,
      widget.info.downloadUrl,
      onProgress: (progress, eta) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _eta = eta;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _errorMessage = "İndirme başarısız oldu. Lütfen internet bağlantınızı kontrol edin.";
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF159D87);

    return AlertDialog(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: accentColor, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.system_update_alt_rounded, color: accentColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'GÜNCELLEME MEVCUT',
              style: const TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  "Mevcut: v${widget.info.currentVersion}",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: accentColor, size: 14),
                const SizedBox(width: 8),
                Text(
                  "Yeni: v${widget.info.latestVersion}",
                  style: const TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "Sürüm Notları:",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                widget.info.changelog,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, height: 1.4),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: accentColor.withValues(alpha: 0.2),
                color: accentColor,
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "%${(_progress * 100).toStringAsFixed(0)} İndiriliyor...",
                    style: const TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  if (_eta.isNotEmpty)
                    Text(
                      "Kalan: $_eta",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.info.forceUpdate && !_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'DAHA SONRA',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor.withValues(alpha: 0.2),
            foregroundColor: accentColor,
            side: const BorderSide(color: accentColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _downloading ? null : _startDownload,
          child: Text(
            _downloading ? 'İNDİRİLİYOR...' : 'ŞİMDİ GÜNCELLE',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
