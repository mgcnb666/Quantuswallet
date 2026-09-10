import 'package:flutter/material.dart';

import 'amount.dart';
import 'mainnet_service.dart';
import 'wallet_controller.dart';

class SendScreen extends StatefulWidget {
  final WalletController controller;

  const SendScreen({super.key, required this.controller});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  final _password = TextEditingController();
  bool _sending = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<PreparedTransfer> _unlockAndPrepare(String recipient, BigInt amount) async {
    final password = _password.text;
    _password.clear();
    return widget.controller.prepareTransfer(recipient: recipient, amount: amount, password: password);
  }

  Future<void> _send() async {
    setState(() => _error = null);
    try {
      setState(() => _sending = true);
      final amount = parseQtc(_amount.text);
      final recipient = _recipient.text.trim();
      if (!widget.controller.mainnet.isValidAddress(recipient)) {
        throw const FormatException('收款地址无效或不是 Quantus qz 地址');
      }

      final prepared = await _unlockAndPrepare(recipient, amount);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认主网转账'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountRow(label: '金额', value: '${formatQtc(prepared.amount)} QTC'),
              const SizedBox(height: 8),
              _AmountRow(label: '当前预估手续费', value: '${formatQtc(prepared.fee)} QTC'),
              const Divider(height: 26),
              _AmountRow(
                label: '预计总计',
                value: '${formatQtc(prepared.amount + prepared.fee)} QTC',
                emphasized: true,
              ),
              const SizedBox(height: 16),
              const Text('收款地址'),
              const SizedBox(height: 6),
              SelectableText(prepared.recipient, style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 16),
              const Text('交易已在本机签名但尚未发送。点击“确认广播”后不可撤销。'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认广播')),
          ],
        ),
      );
      if (confirmed != true) return;

      final receipt = await widget.controller.submitPreparedTransfer(prepared);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('交易已提交'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('手续费：${formatQtc(receipt.fee)} QTC'),
              const SizedBox(height: 12),
              const Text('交易哈希'),
              const SizedBox(height: 6),
              SelectableText(receipt.hash, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发送 QTC')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _recipient,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: '收款 qz 地址'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '金额', suffixText: 'QTC'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: '钱包密码',
                    helperText: '密码仅用于本次本地解密和签名',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(_sending ? '验证并签名中…' : '验证密码并检查手续费'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AmountRow({required this.label, required this.value, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        const SizedBox(width: 16),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: style)),
      ],
    );
  }
}
