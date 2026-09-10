import 'package:flutter/material.dart';

import 'wallet_controller.dart';

class PasswordSetupScreen extends StatefulWidget {
  final WalletController controller;

  const PasswordSetupScreen({super.key, required this.controller});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    _confirmation
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _protect() async {
    setState(() => _error = null);
    try {
      await widget.controller.protectLegacyWallet(
        password: _password.text,
        confirmation: _confirmation.text,
      );
      _password.clear();
      _confirmation.clear();
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
                  const Icon(Icons.enhanced_encryption, size: 54, color: Color(0xFFFF6B2C)),
                  const SizedBox(height: 18),
                  Text('设置钱包密码', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  const Text('检测到旧版钱包。设置密码后，原助记词会重新加密，并删除旧的无密码存储副本。'),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: '新钱包密码',
                      helperText: '至少 10 个字符',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: '再次输入密码'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: widget.controller.loading ? null : _protect,
                    icon: const Icon(Icons.lock),
                    label: Text(widget.controller.loading ? '正在加密…' : '加密并继续'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '密码不会保存在设备中。忘记密码后，需要移除钱包并用助记词重新导入。',
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
