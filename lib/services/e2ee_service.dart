import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:pointycastle/api.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';

class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  E2EEService._internal();

  /// Generates a new RSA Keypair, saves private key locally, returns public key as string
  Future<String> initializeKeypair(String uid) async {
    // Check if we already have a keypair to prevent overwriting existing identity
    final existingPrivateKey = await _secureStorage.read(key: 'private_key_$uid');
    if (existingPrivateKey != null) {
      try {
        final privKey = RsaKeyHelper().parsePrivateKeyFromPem(existingPrivateKey);
        if (privKey.modulus != null && privKey.publicExponent != null) {
          final pubKey = RSAPublicKey(privKey.modulus!, privKey.publicExponent!);
          return RsaKeyHelper().encodePublicKeyToPemPKCS1(pubKey);
        }
      } catch (e) {
        // Fallback to regenerate if corrupt
      }
    }

    // Generate new keypair
    var helper = RsaKeyHelper();
    crypto.AsymmetricKeyPair keyPair = await helper.computeRSAKeyPair(helper.getSecureRandom());
    
    RSAPublicKey publicKey = keyPair.publicKey as RSAPublicKey;
    RSAPrivateKey privateKey = keyPair.privateKey as RSAPrivateKey;

    String pubKeyStr = helper.encodePublicKeyToPemPKCS1(publicKey);
    String privKeyStr = helper.encodePrivateKeyToPemPKCS1(privateKey);

    await _secureStorage.write(key: 'private_key_$uid', value: privKeyStr);

    return pubKeyStr;
  }

  Future<RSAPrivateKey?> _getPrivateKey(String uid) async {
    final privStr = await _secureStorage.read(key: 'private_key_$uid');
    if (privStr == null) return null;
    return RsaKeyHelper().parsePrivateKeyFromPem(privStr);
  }

  Future<String?> exportPrivateKey(String uid) async {
    return await _secureStorage.read(key: 'private_key_$uid');
  }

  Future<void> importPrivateKey(String uid, String privateKeyStr) async {
    await _secureStorage.write(key: 'private_key_$uid', value: privateKeyStr);
  }

  /// Encrypts an AES room key using a user's RSA Public Key
  String encryptRoomKey(String aesKeyBase64, String publicKeyPem) {
    RSAPublicKey pubKey = RsaKeyHelper().parsePublicKeyFromPem(publicKeyPem);
    final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: pubKey));
    final encrypted = encrypter.encrypt(aesKeyBase64);
    return encrypted.base64;
  }

  /// Decrypts the room's AES key using the user's RSA Private Key
  Future<String?> decryptRoomKey(String encryptedAesKeyBase64, String uid) async {
    final privKey = await _getPrivateKey(uid);
    if (privKey == null) return null;
    
    final encrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privKey));
    try {
      final decrypted = encrypter.decrypt64(encryptedAesKeyBase64);
      return decrypted;
    } catch (e) {
      return null;
    }
  }

  /// Generate a random AES 256 key for a new room
  String generateRandomRoomKey() {
    final key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }
}
