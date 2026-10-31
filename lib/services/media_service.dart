import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';
import '../utils/app_strings.dart';
import 'crypto_service.dart';
import 'preferences_service.dart';

class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Take a photo instantly using the camera
  Future<File?> takePhoto() async {
    await Permission.camera.request();
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) return File(photo.path);
    return null;
  }

  /// Record a video instantly using the camera
  Future<File?> recordVideo() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) return File(video.path);
    return null;
  }

  /// Pick multiple assets (images/videos) using wechat_assets_picker
  Future<List<AssetEntity>> pickAssets(BuildContext context) async {
    if (Platform.isAndroid) {
      await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();
    } else if (Platform.isIOS) {
      await Permission.photos.request();
    }

    if (!context.mounted) return [];

    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 15,
        requestType: RequestType.common, // Images and videos
        themeColor: Color(0xFF159D87), // Matrix green
      ),
    );
    return result ?? [];
  }

  /// Crop an image
  Future<File?> cropImage(File imageFile) async {
    final strings = AppStrings(await PreferencesService.getLanguage());
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: strings.editMediaTitle,
          toolbarColor: Colors.black,
          toolbarWidgetColor: const Color(0xFF159D87),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          activeControlsWidgetColor: const Color(0xFF159D87),
          backgroundColor: Colors.black,
          dimmedLayerColor: Colors.black54,
        ),
        IOSUiSettings(title: strings.editMediaTitle),
      ],
    );
    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  /// Compress image based on quality setting. Ignores videos based on extension.
  Future<File?> compressImage(File file, bool isHD) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi') return file;
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.absolute.path}/${const Uuid().v4()}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: isHD ? 90 : 70,
      minWidth: isHD ? 2048 : 1024,
      minHeight: isHD ? 2048 : 1024,
      format: CompressFormat.jpeg,
    );

    if (result != null) {
      return File(result.path);
    }
    return null;
  }

  /// Compress video using video_compress
  Future<File?> compressVideo(File file) async {
    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    if (mediaInfo != null && mediaInfo.file != null) {
      return mediaInfo.file;
    }
    return file; // Return original if compression fails
  }

  /// Generate video thumbnail using video_compress
  Future<File?> getVideoThumbnail(File file) async {
    final thumbnailFile = await VideoCompress.getFileThumbnail(
      file.path,
      quality: 50,
      position: -1, // Use -1 to get the best frame
    );
    return thumbnailFile;
  }

  /// Upload file to Firebase Storage under rooms/{roomId}/
  Future<String?> uploadMedia(
    File file,
    String roomId,
    Function(double) onProgress,
  ) async {
    try {
      final fileName = const Uuid().v4();
      final extension = file.path.split('.').last.toLowerCase();
      final hashedRoomId = CryptoService.deriveRoomId(roomId);
      final ref = _storage.ref().child('rooms/$hashedRoomId/$fileName.$extension');

      SettableMetadata? metadata;
      if (extension == 'm4a') {
        metadata = SettableMetadata(contentType: 'audio/m4a');
      } else if (extension == 'mp4') {
        metadata = SettableMetadata(contentType: 'video/mp4');
      } else if (extension == 'jpg' || extension == 'jpeg') {
        metadata = SettableMetadata(contentType: 'image/jpeg');
      }

      final uploadTask = metadata != null
          ? ref.putFile(file, metadata)
          : ref.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  /// Delete media file from Firebase Storage
  Future<void> deleteMediaFile(String url) async {
    if (!url.contains('firebasestorage')) return;
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Delete media error: $e');
    }
  }
}
