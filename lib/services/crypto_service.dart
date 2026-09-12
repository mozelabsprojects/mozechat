import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';

// Arka plan iş parçacığı (Isolate) için toplu şifre çözücü
List<String?> _decryptBatchIsolate(Map<String, dynamic> args) {
  final cipherList = args['cipherList'] as List<Map<String, String?>>;
  final keyBytes = args['key'] as Uint8List;
  final key = encrypt.Key(keyBytes);
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

  return cipherList.map((item) {
    final cipherText = item['cipherText'];
    final ivBase64 = item['ivBase64'];
    if (cipherText == null || ivBase64 == null) return null;

    try {
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypted = encrypt.Encrypted.fromBase64(cipherText);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return "[Şifre Çözülemedi]";
    }
  }).toList();
}

Map<String, String> _encryptIsolate(Map<String, dynamic> args) {
  final plainText = args['plainText'] as String;
  final keyBytes = args['key'] as Uint8List;
  final key = encrypt.Key(keyBytes);
  final iv = encrypt.IV.fromLength(16);
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  final encrypted = encrypter.encrypt(plainText, iv: iv);
  return {
    'cipherText': encrypted.base64,
    'ivBase64': iv.base64,
  };
}

class CryptoService {
  // --- SEED PHRASE & IDENTITY METHODS ---

  static String generateSeedPhrase() {
    return bip39.generateMnemonic();
  }

  static String getAuthEmailFromSeed(String seedPhrase) {
    final bytes = utf8.encode(seedPhrase.trim().toLowerCase());
    final digest = sha256.convert(bytes);
    final hex = digest.toString().substring(0, 32);
    return '$hex@mozechat.anon';
  }

  static String getAuthPasswordFromSeed(String seedPhrase) {
    final bytes = utf8.encode("${seedPhrase.trim().toLowerCase()}_password_salt");
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static encrypt.Key deriveKeyFromSeed(String seedPhrase) {
    final salt = utf8.encode("seed_phrase_key_salt_mozechat");
    final bytes = utf8.encode(seedPhrase.trim().toLowerCase());
    final hmac = Hmac(sha256, salt);
    final digest = hmac.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }
  
  // --------------------------------------
  // Oda kodundan veritabanında kullanılacak güvenli bir döküman ID'si türetir.
  // Böylece veritabanında oda kodunun kendisi açıkça tutulmaz.
  static String deriveRoomId(String roomCode) {
    final salt = utf8.encode("room_id_salt_mozechat");
    final codeBytes = utf8.encode(roomCode);
    final hmac = Hmac(sha256, salt);
    final digest = hmac.convert(codeBytes);
    return digest.toString(); // 64 karakterlik hex string
  }

  // Oda kodundan AES-256 şifreleme anahtarı (32 byte) türetir.
  static encrypt.Key deriveEncryptionKey(String roomCode) {
    final salt = utf8.encode("encryption_key_salt_mozechat");
    final codeBytes = utf8.encode(roomCode);
    final hmac = Hmac(sha256, salt);
    final digest = hmac.convert(codeBytes);
    // sha256 32 byte üretir, bu da AES-256 için tam olarak gereken uzunluktur.
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  // Mesajı şifreler. Geriye şifreli metin (Base64) ve IV (Base64) döner.
  static EncryptedMessage encryptMessage(String plainText, encrypt.Key key) {
    // Her mesaj için rastgele bir Initialization Vector (IV) üretilmeli.
    final iv = encrypt.IV.fromLength(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return EncryptedMessage(cipherText: encrypted.base64, ivBase64: iv.base64);
  }

  // Şifreli mesajı çözer ve yalın metni (plain text) döndürür.
  static String decryptMessage(
    String cipherText,
    String ivBase64,
    encrypt.Key key,
  ) {
    try {
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final encrypted = encrypt.Encrypted.fromBase64(cipherText);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      return decrypted;
    } catch (e) {
      return "[Şifre Çözülemedi]";
    }
  }

  // --- ISOLATE TABANLI ASENKRON METOTLAR (PERFORMANS) ---
  
  static Future<EncryptedMessage> encryptMessageAsync(String plainText, encrypt.Key key) async {
    final result = await compute(_encryptIsolate, {
      'plainText': plainText,
      'key': key.bytes,
    });
    return EncryptedMessage(cipherText: result['cipherText']!, ivBase64: result['ivBase64']!);
  }

  static Future<List<String?>> decryptMessageBatchAsync(
    List<Map<String, String?>> cipherList,
    encrypt.Key key,
  ) async {
    // Liste boşsa compute çağırmaya gerek yok
    if (cipherList.isEmpty) return [];
    
    return await compute(_decryptBatchIsolate, {
      'cipherList': cipherList,
      'key': key.bytes,
    });
  }

  // Rastgele, güvenli bir oda kodu (12 karakter) oluşturur.
  static String generateSecureRoomCode() {
    final randomBytes = encrypt.IV
        .fromLength(9)
        .bytes; // 9 bytes = 12 base64 chars
    final base64String = base64UrlEncode(randomBytes);
    return base64String.replaceAll('=', '').toUpperCase();
  }
}

class EncryptedMessage {
  final String cipherText;
  final String ivBase64;

  EncryptedMessage({required this.cipherText, required this.ivBase64});
}
