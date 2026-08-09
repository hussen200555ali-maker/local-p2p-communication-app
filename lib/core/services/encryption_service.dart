import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'log_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const String _passphrase = 'LocalSocialApp2024!@#EncKey_v1';
  encrypt.Key? _key;

  Future<void> init() async {
    if (_key != null) return;
    final hashBytes = sha256.convert(utf8.encode(_passphrase)).bytes;
    _key = encrypt.Key.fromBase64(base64Encode(hashBytes));
  }

  String encryptText(String plaintext) {
    if (_key == null) throw StateError('EncryptionService not initialized');
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  String decryptText(String ciphertext) {
    if (_key == null) throw StateError('EncryptionService not initialized');
    final parts = ciphertext.split(':');
    if (parts.length != 2) return ciphertext;
    try {
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      LogService.e('H5 decryptText FAILED for ciphertext len=${ciphertext.length}: $e');
      return ciphertext;
    }
  }
}