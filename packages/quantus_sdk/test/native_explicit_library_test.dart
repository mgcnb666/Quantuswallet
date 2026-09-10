@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final libraryPath = '${Directory.current.path}/rust/target/release/librust_lib_quantus_wallet.dylib';
    await RustLib.init(externalLibrary: ExternalLibrary.open(libraryPath));
    await SettingsService().initialize();
    setDefaultSs58Prefix(prefix: 189);
  });

  test('ML-DSA-65 and ML-DSA-87 match official address vectors', () {
    const mnemonic =
        'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';

    final current = HdWalletService().keyPairAtIndex(mnemonic, 0, DilithiumScheme.mlDsa65);
    final legacy = HdWalletService().keyPairAtIndex(mnemonic, 0, DilithiumScheme.mlDsa87);

    expect(current.ss58Address, 'qzoyC4eRTrexYoutXABVsf61QJZxJim3iWvayRQwEjXWgA4mw');
    expect(legacy.ss58Address, 'qzm5QCox8Dp5A3oSXZZYHD8YoYgPz7enykZb6RPUropdCyN5h');
  });

  test('spec 152 signatures use the mainnet signing context', () {
    const mnemonic =
        'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';
    final keypair = HdWalletService().keyPairAtIndex(mnemonic, 0, DilithiumScheme.mlDsa65);
    final message = <int>[1, 2, 3, 4, 5];
    final signature = keypair.sign(message, specVersion: 152);

    expect(verifyMessage(keypair: keypair, message: message, signature: signature, specVersion: 152), isTrue);
    expect(verifyMessage(keypair: keypair, message: message, signature: signature, specVersion: 147), isFalse);
  });
}
