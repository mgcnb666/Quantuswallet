import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_lite_wallet/src/wallet_vault.dart';

void main() {
  const cipher = WalletCipher(memoryKiB: 1024, iterations: 1, parallelism: 1);
  const mnemonic =
      'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';
  const password = 'correct horse battery staple';
  const context = 'qz-test|m/44';

  test('password validation requires confirmation and sufficient length', () {
    expect(() => WalletCipher.validateNewPassword('short', 'short'), throwsA(isA<VaultException>()));
    expect(() => WalletCipher.validateNewPassword(password, 'different value'), throwsA(isA<VaultException>()));
    expect(() => WalletCipher.validateNewPassword(password, password), returnsNormally);
  });

  test('round trips without placing mnemonic or password in envelope', () async {
    final envelope = await cipher.encryptMnemonic(mnemonic: mnemonic, password: password, context: context);
    expect(envelope, isNot(contains(mnemonic)));
    expect(envelope, isNot(contains(password)));
    expect(await cipher.decryptMnemonic(envelope: envelope, password: password, context: context), mnemonic);
  });

  test('rejects a wrong password, wrong context, and tampering', () async {
    final envelope = await cipher.encryptMnemonic(mnemonic: mnemonic, password: password, context: context);
    await expectLater(
      cipher.decryptMnemonic(envelope: envelope, password: 'wrong password value', context: context),
      throwsA(isA<VaultException>()),
    );
    await expectLater(
      cipher.decryptMnemonic(envelope: envelope, password: password, context: 'different-account'),
      throwsA(isA<VaultException>()),
    );

    final json = jsonDecode(envelope) as Map<String, dynamic>;
    final data = base64Url.decode(json['data'] as String);
    data[0] ^= 1;
    json['data'] = base64UrlEncode(data);
    await expectLater(
      cipher.decryptMnemonic(envelope: jsonEncode(json), password: password, context: context),
      throwsA(isA<VaultException>()),
    );
  });
}
