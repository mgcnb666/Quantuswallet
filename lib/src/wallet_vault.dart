import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartArgon2id;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultException implements Exception {
  final String message;

  const VaultException(this.message);

  @override
  String toString() => message;
}

/// Password-based authenticated encryption for a single mnemonic.
///
/// The envelope is self-describing, but this implementation deliberately only
/// accepts its exact v1 parameters so a modified envelope cannot force an
/// excessive-memory KDF operation.
class WalletCipher {
  static const productionMemoryKiB = 65536;
  static const productionIterations = 3;
  static const productionParallelism = 1;
  static const _version = 1;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const WalletCipher({
    this.memoryKiB = productionMemoryKiB,
    this.iterations = productionIterations,
    this.parallelism = productionParallelism,
  });

  static void validateNewPassword(String password, String confirmation) {
    if (password != confirmation) throw const VaultException('两次输入的密码不一致');
    if (password.runes.length < 10) throw const VaultException('钱包密码至少需要 10 个字符');
    if (utf8.encode(password).length > 256) throw const VaultException('钱包密码过长');
    if (password.trim().isEmpty) throw const VaultException('钱包密码不能全部为空格');
  }

  Future<String> encryptMnemonic({
    required String mnemonic,
    required String password,
    required String context,
  }) async {
    final saltSecret = SecretKeyData.random(length: _saltLength);
    final salt = Uint8List.fromList(saltSecret.bytes);
    saltSecret.destroy();

    final cipher = AesGcm.with256bits();
    final nonce = cipher.newNonce();
    final aad = utf8.encode(_aad(context));
    final clearText = Uint8List.fromList(utf8.encode(mnemonic));
    final key = await _deriveKey(password: password, salt: salt, aad: aad);
    try {
      final box = await cipher.encrypt(
        clearText,
        secretKey: key,
        nonce: nonce,
        aad: aad,
      );
      return jsonEncode({
        'v': _version,
        'kdf': 'argon2id',
        'm': memoryKiB,
        't': iterations,
        'p': parallelism,
        'salt': base64UrlEncode(salt),
        'cipher': 'aes-256-gcm',
        'nonce': base64UrlEncode(box.nonce),
        'data': base64UrlEncode(box.cipherText),
        'mac': base64UrlEncode(box.mac.bytes),
      });
    } finally {
      clearText.fillRange(0, clearText.length, 0);
      key.destroy();
    }
  }

  Future<String> decryptMnemonic({
    required String envelope,
    required String password,
    required String context,
  }) async {
    if (envelope.length > 8192) throw const VaultException('钱包密文格式无效');

    try {
      final json = jsonDecode(envelope) as Map<String, dynamic>;
      if (json['v'] != _version ||
          json['kdf'] != 'argon2id' ||
          json['m'] != memoryKiB ||
          json['t'] != iterations ||
          json['p'] != parallelism ||
          json['cipher'] != 'aes-256-gcm') {
        throw const VaultException('钱包密文版本或加密参数不受支持');
      }

      final salt = _decode(json['salt'], expectedLength: _saltLength);
      final nonce = _decode(json['nonce'], expectedLength: _nonceLength);
      final mac = _decode(json['mac'], expectedLength: _macLength);
      final cipherText = _decode(json['data'], maxLength: 1024);
      if (cipherText.isEmpty) throw const VaultException('钱包密文格式无效');

      final aad = utf8.encode(_aad(context));
      final key = await _deriveKey(password: password, salt: salt, aad: aad);
      List<int>? clearText;
      try {
        clearText = await AesGcm.with256bits().decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
          aad: aad,
        );
        return utf8.decode(clearText);
      } on SecretBoxAuthenticationError {
        throw const VaultException('钱包密码错误或本地密文已损坏');
      } finally {
        if (clearText != null) clearText.fillRange(0, clearText.length, 0);
        key.destroy();
      }
    } on VaultException {
      rethrow;
    } on FormatException {
      throw const VaultException('钱包密文格式无效');
    } on TypeError {
      throw const VaultException('钱包密文格式无效');
    }
  }

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
    required List<int> aad,
  }) async {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final state = DartArgon2id(
      memory: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: 32,
    ).newState();
    try {
      final derivedBytes = await state.deriveKeyBytes(
        password: passwordBytes,
        nonce: salt,
        associatedData: aad,
      );
      return SecretKeyData(derivedBytes, overwriteWhenDestroyed: true);
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
      state.tryReleaseMemory();
    }
  }

  Uint8List _decode(dynamic value, {int? expectedLength, int? maxLength}) {
    if (value is! String) throw const VaultException('钱包密文格式无效');
    final bytes = Uint8List.fromList(base64Url.decode(value));
    if ((expectedLength != null && bytes.length != expectedLength) ||
        (maxLength != null && bytes.length > maxLength)) {
      throw const VaultException('钱包密文格式无效');
    }
    return bytes;
  }

  String _aad(String context) => 'quantus-lite-wallet|vault-v1|$context';
}

class WalletVault {
  static const _storageKey = 'mnemonic_envelope_v1';

  final FlutterSecureStorage _storage;
  final WalletCipher cipher;

  WalletVault({FlutterSecureStorage? storage, this.cipher = const WalletCipher()})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'quantus_lite_wallet_vault_v1',
              resetOnError: false,
              keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
              storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
            ),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
          );

  Future<bool> exists() async => await _storage.read(key: _storageKey) != null;

  Future<void> storeMnemonic({
    required String mnemonic,
    required String password,
    required String context,
  }) async {
    final envelope = await cipher.encryptMnemonic(mnemonic: mnemonic, password: password, context: context);
    await _storage.write(key: _storageKey, value: envelope);
  }

  Future<String> readMnemonic({required String password, required String context}) async {
    final envelope = await _storage.read(key: _storageKey);
    if (envelope == null) throw const VaultException('本机没有加密钱包，请重新导入助记词');
    return cipher.decryptMnemonic(envelope: envelope, password: password, context: context);
  }

  Future<void> delete() => _storage.delete(key: _storageKey);
}
