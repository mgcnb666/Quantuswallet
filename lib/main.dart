import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'src/app.dart';
import 'src/wallet_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuantusSdk.init();

  final controller = WalletController();
  await controller.initialize();
  runApp(QuantusLiteWalletApp(controller: controller));
}
