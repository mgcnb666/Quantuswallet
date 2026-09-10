import 'package:flutter/material.dart';

import 'import_wallet_screen.dart';
import 'password_setup_screen.dart';
import 'theme.dart';
import 'wallet_controller.dart';
import 'wallet_screen.dart';

class QuantusLiteWalletApp extends StatelessWidget {
  final WalletController controller;

  const QuantusLiteWalletApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantus Lite Wallet',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.account == null) return ImportWalletScreen(controller: controller);
          if (controller.needsPasswordSetup) return PasswordSetupScreen(controller: controller);
          return WalletScreen(controller: controller);
        },
      ),
    );
  }
}
