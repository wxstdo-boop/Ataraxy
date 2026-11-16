import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Password-based encryption for JSON backups.
///
/// The on-disk format is a self-describing envelope so a backup is never
/// confused with the legacy plaintext JSON:
///
/// ```json
/// {
///   "app": "Ataraxy",
///   "format": "ataraxy-encrypted-backup",
///   "version": 1,
///   "kdf": "PBKDF2-HMAC-SHA256",
///   "iterations": 210000,
///   "cipher": "AES-256-GCM",
///   "salt": "<base64>",
///   "nonce": "<base64>",
///   "mac": "<base64>",
///   "payload": "<base64 ciphertext>"
/// }
/// ```
///
/// The key is derived with PBKDF2-HMAC-SHA256 (210 000 iterations) and the
/// payload sealed with AES-256-GCM, whose authentication tag doubles as a
/// password check: a wrong password fails [decrypt] with
/// [BackupPasswordException] instead of returning garbage.
class BackupCrypto {
  static const String formatTag = 'ataraxy-encrypted-backup';
  static const int _iterations = 210000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  static final _algorithm = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  /// True when [raw] looks like an encrypted backup envelope (rather than a
  /// legacy plaintext JSON backup). Used by the import path to decide
  /// whether it must ask the user for a password.
  static bool isEncrypted(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded['format'] == formatTag;
    } catch (_) {
      return false;
    }
  }

  /// Encrypts [plaintext] (a JSON string) under [password] and returns the
  /// envelope as a pretty-printed JSON string.
  static Future<String> encrypt(String plaintext, String password) async {
    final rnd = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => rnd.nextInt(256)),
    );
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => rnd.nextInt(256)),
    );

    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Ataraxy',
      'format': formatTag,
      'version': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'payload': base64Encode(box.cipherText),
    });
  }

  /// Decrypts an envelope produced by [encrypt]. Throws
  /// [BackupPasswordException] when the password is wrong (the GCM tag
  /// fails to verify) and [FormatException] when [raw] is not an envelope.
  static Future<String> decrypt(String raw, String password) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['format'] != formatTag) {
      throw const FormatException('Not an Ataraxy encrypted backup');
    }

    final salt = base64Decode(decoded['salt'] as String);
    final nonce = base64Decode(decoded['nonce'] as String);
    final mac = Mac(base64Decode(decoded['mac'] as String));
    final cipherText = base64Decode(decoded['payload'] as String);

    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupPasswordException();
    }
  }
}

/// Raised when a backup password is wrong (GCM authentication failed).
class BackupPasswordException implements Exception {
  const BackupPasswordException();

  @override
  String toString() => 'BackupPasswordException';
}
