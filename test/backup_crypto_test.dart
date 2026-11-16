import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/services/backup_crypto.dart';

void main() {
  const plaintext = '{"app":"Ataraxy","entries":[{"id":"e1","title":"Сон"}]}';

  test('encrypt → decrypt round-trips the payload', () async {
    final sealed = await BackupCrypto.encrypt(plaintext, 'hunter2');
    expect(BackupCrypto.isEncrypted(sealed), isTrue);

    final opened = await BackupCrypto.decrypt(sealed, 'hunter2');
    expect(opened, plaintext);
  });

  test('the ciphertext never contains the plaintext', () async {
    final sealed = await BackupCrypto.encrypt(plaintext, 'hunter2');
    expect(sealed.contains('e1'), isFalse);
    expect(sealed.contains('Сон'), isFalse);
  });

  test('the envelope is self-describing JSON', () async {
    final sealed = await BackupCrypto.encrypt(plaintext, 'pw');
    final env = jsonDecode(sealed) as Map<String, dynamic>;
    expect(env['format'], BackupCrypto.formatTag);
    expect(env['cipher'], 'AES-256-GCM');
    expect(env['salt'], isNotEmpty);
    expect(env['nonce'], isNotEmpty);
    expect(env['mac'], isNotEmpty);
  });

  test('a wrong password fails authentication', () async {
    final sealed = await BackupCrypto.encrypt(plaintext, 'correct');
    await expectLater(
      BackupCrypto.decrypt(sealed, 'wrong'),
      throwsA(isA<BackupPasswordException>()),
    );
  });

  test('a plaintext backup is not mistaken for an encrypted one', () {
    expect(BackupCrypto.isEncrypted(plaintext), isFalse);
    expect(BackupCrypto.isEncrypted('not json at all'), isFalse);
  });

  test('two encryptions of the same data differ (random salt/nonce)',
      () async {
    final a = await BackupCrypto.encrypt(plaintext, 'pw');
    final b = await BackupCrypto.encrypt(plaintext, 'pw');
    expect(a, isNot(b));
  });
}
