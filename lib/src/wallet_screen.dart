import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'amount.dart';
import 'send_screen.dart';
import 'wallet_controller.dart';

class WalletScreen extends StatelessWidget {
  final WalletController controller;

  const WalletScreen({super.key, required this.controller});

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除本地钱包？'),
        content: const Text('这会删除本机安全存储中的助记词。请先确认你已离线备份助记词。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeWallet();
  }

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quantus 主网'),
        actions: [
          IconButton(
            onPressed: controller.loading ? null : () => controller.refreshBalance(),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') _remove(context);
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('移除本地钱包'))],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('可用余额', style: TextStyle(color: Color(0xFF9DA3AE))),
                      const SizedBox(height: 8),
                      Text(
                        controller.balance == null
                            ? '—'
                            : '${formatQtc(controller.balance!, maxFractionDigits: 6)} QTC',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (controller.loading)
                        const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                      if (controller.lastError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            controller.lastError.toString().replaceFirst('Exception: ', ''),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('钱包地址', style: TextStyle(color: Color(0xFF9DA3AE))),
                      const SizedBox(height: 10),
                      SelectableText(account.accountId, style: const TextStyle(fontFamily: 'monospace', height: 1.5)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: account.accountId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('地址已复制')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制地址'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SendScreen(controller: controller)),
                      ),
                icon: const Icon(Icons.north_east),
                label: const Text('转账'),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Mainnet · rpc1/rpc2 自动故障切换 · 本地 ML-DSA 签名',
                  style: TextStyle(color: Color(0xFF7E8490), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
