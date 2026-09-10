import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_lite_wallet/src/wallet_vault.dart';

void main() {
  test('production Argon2id profile benchmark', () async {
    const cipher = WalletCipher();
    const mnemonic =
        'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';
    const password = 'benchmark password only';
    const context = 'benchmark-address|benchmark-path|ml-dsa-65';

    final encryptWatch = Stopwatch()..start();
    final envelope = await cipher.encryptMnemonic(mnemonic: mnemonic, password: password, context: context);
    encryptWatch.stop();

    final decryptWatch = Stopwatch()..start();
    final result = await cipher.decryptMnemonic(envelope: envelope, password: password, context: context);
    decryptWatch.stop();
    expect(result, mnemonic);

    // ignore: avoid_print
    print('encrypt_ms=${encryptWatch.elapsedMilliseconds} decrypt_ms=${decryptWatch.elapsedMilliseconds}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
