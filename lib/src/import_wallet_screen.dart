import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'wallet_controller.dart';
import 'wallet_vault.dart';

class ImportWalletScreen extends StatefulWidget {
  final WalletController controller;

  const ImportWalletScreen({super.key, required this.controller});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _mnemonic = TextEditingController();
  final _expectedAddress = TextEditingController();
  final _accountIndex = TextEditingController(text: '0');
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  DilithiumScheme _scheme = DilithiumSchemeExtension.current;
  bool _obscure = true;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _mnemonic
      ..clear()
      ..dispose();
    _expectedAddress.dispose();
    _accountIndex.dispose();
    _password
      ..clear()
      ..dispose();
    _passwordConfirmation
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _error = null);
    try {
      WalletCipher.validateNewPassword(_password.text, _passwordConfirmation.text);
      final index = int.parse(_accountIndex.text.trim());
      final address = await widget.controller.deriveAddress(
        mnemonic: _mnemonic.text.trim(),
        accountIndex: index,
        scheme: _scheme,
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认派生地址'),
          content: SelectableText(address),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('加密保存')),
          ],
        ),
      );
      if (confirmed != true) return;

      await widget.controller.importWallet(
        mnemonic: _mnemonic.text,
        accountIndex: index,
        scheme: _scheme,
        password: _password.text,
        passwordConfirmation: _passwordConfirmation.text,
        expectedAddress: _expectedAddress.text,
      );
      _mnemonic.clear();
      _password.clear();
      _passwordConfirmation.clear();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Q',
                    style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Color(0xFFFF6B2C)),
                  ),
                  const SizedBox(height: 12),
                  Text('Quantus Lite Wallet', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('仅连接 Quantus 主网。助记词先用钱包密码加密，再保存到系统安全存储，不会上传。'),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _mnemonic,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    minLines: 4,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: '12 或 24 个助记词',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<DilithiumScheme>(
                    initialValue: _scheme,
                    decoration: const InputDecoration(labelText: '地址方案'),
                    items: const [
                      DropdownMenuItem(value: DilithiumScheme.mlDsa65, child: Text('ML-DSA-65（当前默认）')),
                      DropdownMenuItem(value: DilithiumScheme.mlDsa87, child: Text('ML-DSA-87（旧钱包）')),
                    ],
                    onChanged: (value) => setState(() => _scheme = value!),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _accountIndex,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '账户索引', helperText: '一般为 0'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _expectedAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: '已知钱包地址（可选）', helperText: '填写后会阻止导入不匹配的助记词或方案'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: '设置钱包密码',
                      helperText: '至少 10 个字符；每次转账都要输入',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordConfirmation,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: '再次输入钱包密码'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: widget.controller.loading ? null : _import,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(widget.controller.loading ? '处理中…' : '导入并加密保存'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '安全提示：密码不会保存，忘记密码只能用助记词重新导入。截图功能可用，但助记词截图可能被相册云同步。',
                    style: TextStyle(color: Color(0xFF9DA3AE), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
