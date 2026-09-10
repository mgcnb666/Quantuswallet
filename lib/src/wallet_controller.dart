import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'mainnet_service.dart';
import 'wallet_vault.dart';

class WalletController extends ChangeNotifier {
  final SettingsService _settings = SettingsService();
  final MainnetService mainnet = MainnetService();
  final WalletVault _vault = WalletVault();

  Account? account;
  BigInt? balance;
  Object? lastError;
  bool loading = false;
  bool needsPasswordSetup = false;

  Future<void> initialize() async {
    final accounts = await _settings.getAccounts();
    account = accounts.isEmpty ? null : accounts.first;
    if (account != null && !await _vault.exists()) {
      if (await _settings.getMnemonic(account!.walletIndex) != null) {
        // Migration path from the first build, which used only Keystore storage.
        needsPasswordSetup = true;
      } else {
        // Public account metadata without an encrypted secret cannot sign.
        await _settings.saveAccounts([]);
        account = null;
      }
    }
    if (account != null) await refreshBalance(silent: true);
  }

  Future<String> deriveAddress({
    required String mnemonic,
    required int accountIndex,
    required DilithiumScheme scheme,
  }) async {
    final normalized = mnemonic.trim().split(RegExp(r'\s+')).join(' ');
    final keypair = HdWalletService().keyPairAtIndex(normalized, accountIndex, scheme);
    try {
      return keypair.ss58Address;
    } finally {
      keypair.secretKey.fillRange(0, keypair.secretKey.length, 0);
    }
  }

  Future<Account> importWallet({
    required String mnemonic,
    required int accountIndex,
    required DilithiumScheme scheme,
    required String password,
    required String passwordConfirmation,
    String? expectedAddress,
  }) async {
    final normalized = mnemonic.trim().split(RegExp(r'\s+')).join(' ');
    final words = normalized.split(' ');
    if (words.length != 12 && words.length != 24) {
      throw const FormatException('助记词必须是 12 或 24 个单词');
    }
    if (accountIndex < 0 || accountIndex > 999) throw const FormatException('账户索引必须在 0–999 之间');
    WalletCipher.validateNewPassword(password, passwordConfirmation);

    _setLoading(true);
    try {
      final path = HdWalletService.pathForIndex(accountIndex, scheme);
      final keypair = HdWalletService().keyPairAtPath(normalized, path, scheme);
      late final Account imported;
      try {
        final derived = keypair.ss58Address;
        final expected = expectedAddress?.trim();
        if (expected != null && expected.isNotEmpty && expected != derived) {
          throw StateError('派生地址与预期地址不一致：$derived');
        }

        imported = Account.derived(
          walletIndex: 0,
          index: accountIndex,
          name: 'Main Wallet',
          keypair: keypair,
          derivationPath: path,
        );
      } finally {
        keypair.secretKey.fillRange(0, keypair.secretKey.length, 0);
      }

      await _vault.storeMnemonic(
        mnemonic: normalized,
        password: password,
        context: _vaultContext(imported),
      );
      try {
        // Remove any value written by the pre-password build before making the
        // new account active. Only the Argon2id/AES-GCM envelope remains.
        await _settings.deleteMnemonic(0);
        await _settings.saveAccounts([imported]);
      } catch (_) {
        await _vault.delete();
        rethrow;
      }

      account = imported;
      balance = null;
      lastError = null;
      notifyListeners();
      unawaited(refreshBalance(silent: true));
      return imported;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshBalance({bool silent = false}) async {
    final current = account;
    if (current == null) return;
    if (!silent) _setLoading(true);
    try {
      balance = await mainnet.balance(current.accountId);
      lastError = null;
    } catch (error) {
      lastError = error;
      if (!silent) rethrow;
    } finally {
      if (!silent) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> protectLegacyWallet({required String password, required String confirmation}) async {
    final current = account;
    if (current == null || !needsPasswordSetup) throw StateError('没有需要升级保护的钱包');
    WalletCipher.validateNewPassword(password, confirmation);

    _setLoading(true);
    try {
      final mnemonic = await _settings.getMnemonic(current.walletIndex);
      if (mnemonic == null) throw StateError('原钱包助记词不存在，请重新导入');
      final signer = HdWalletService().keyPairAtPath(mnemonic, current.derivationPath!, current.scheme!);
      try {
        if (signer.ss58Address != current.accountId) {
          throw StateError('原钱包助记词与保存的地址不匹配，请重新导入');
        }
      } finally {
        signer.secretKey.fillRange(0, signer.secretKey.length, 0);
      }

      await _vault.storeMnemonic(
        mnemonic: mnemonic,
        password: password,
        context: _vaultContext(current),
      );
      try {
        final check = await _vault.readMnemonic(password: password, context: _vaultContext(current));
        if (check != mnemonic) throw StateError('加密钱包校验失败');
        await _settings.deleteMnemonic(current.walletIndex);
      } catch (_) {
        await _vault.delete();
        rethrow;
      }

      needsPasswordSetup = false;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<PreparedTransfer> prepareTransfer({
    required String recipient,
    required BigInt amount,
    required String password,
  }) async {
    final current = account;
    if (current == null) throw StateError('尚未导入钱包');
    if (needsPasswordSetup) throw StateError('请先设置钱包密码');
    if (password.isEmpty) throw const VaultException('请输入钱包密码');

    final mnemonic = await _vault.readMnemonic(password: password, context: _vaultContext(current));
    final signer = HdWalletService().keyPairAtPath(mnemonic, current.derivationPath!, current.scheme!);
    try {
      if (signer.ss58Address != current.accountId) {
        throw const VaultException('解密出的助记词与钱包地址不匹配');
      }
      return await mainnet.prepareTransfer(
        account: current,
        signer: signer,
        recipient: recipient,
        amount: amount,
      );
    } finally {
      signer.secretKey.fillRange(0, signer.secretKey.length, 0);
    }
  }

  Future<TransferReceipt> submitPreparedTransfer(PreparedTransfer prepared) async {
    if (account == null) throw StateError('尚未导入钱包');
    _setLoading(true);
    try {
      final receipt = await mainnet.submitPreparedTransfer(prepared);
      await Future<void>.delayed(const Duration(seconds: 2));
      await refreshBalance(silent: true);
      return receipt;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeWallet() async {
    _setLoading(true);
    try {
      await _settings.deleteMnemonic(0);
      await _vault.delete();
      await _settings.saveAccounts([]);
      account = null;
      balance = null;
      lastError = null;
      needsPasswordSetup = false;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  String _vaultContext(Account value) {
    final path = value.derivationPath;
    final scheme = value.scheme;
    if (path == null || scheme == null) throw StateError('钱包缺少派生信息');
    return '${value.accountId}|$path|${scheme.storageName}';
  }
}
