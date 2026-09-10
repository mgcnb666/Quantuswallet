import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class MainnetInfo {
  final String chain;
  final String genesisHash;
  final int specVersion;
  final int transactionVersion;

  const MainnetInfo({
    required this.chain,
    required this.genesisHash,
    required this.specVersion,
    required this.transactionVersion,
  });
}

class TransferReceipt {
  final String hash;
  final BigInt fee;

  const TransferReceipt({required this.hash, required this.fee});
}

class PreparedTransfer {
  final Uint8List payload;
  final String recipient;
  final BigInt amount;
  final BigInt fee;
  final DateTime createdAt;

  PreparedTransfer({
    required Uint8List payload,
    required this.recipient,
    required this.amount,
    required this.fee,
  }) : payload = Uint8List.fromList(payload),
       createdAt = DateTime.now();
}

class MainnetService {
  static const expectedGenesisHash = '0xfb5487c0be6ae4ade2d41d16e50465129861636c2b8d61fa94d7a19631626fba';
  static const supportedSpecVersion = 152;
  static const supportedTransactionVersion = 6;

  final SubstrateService _substrate = SubstrateService();
  final RpcEndpointService _rpc = RpcEndpointService();

  Future<dynamic> _call(String method, [List<dynamic> params = const []]) async {
    final response = await _rpc.post(body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}));
    if (response.statusCode != 200) throw StateError('RPC HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['error'] != null) throw StateError('RPC $method: ${decoded['error']}');
    return decoded['result'];
  }

  Future<MainnetInfo> verifyMainnet() async {
    final chain = (await _call('system_chain')).toString();
    final genesisHash = (await _call('chain_getBlockHash', [0])).toString().toLowerCase();
    final runtime = await _call('state_getRuntimeVersion') as Map<String, dynamic>;
    final specVersion = runtime['specVersion'] as int;
    final transactionVersion = runtime['transactionVersion'] as int;

    if (genesisHash != expectedGenesisHash) {
      throw StateError('网络 genesis 不匹配，已禁止读取和签名');
    }
    if (specVersion != supportedSpecVersion || transactionVersion != supportedTransactionVersion) {
      throw StateError('主网运行时已变化（当前 spec $specVersion / tx $transactionVersion），请先更新应用，转账已被禁止');
    }

    return MainnetInfo(
      chain: chain,
      genesisHash: genesisHash,
      specVersion: specVersion,
      transactionVersion: transactionVersion,
    );
  }

  Future<BigInt> balance(String address) async {
    await verifyMainnet();
    return _substrate.queryBalance(address);
  }

  bool isValidAddress(String address) => _substrate.isValidSS58Address(address.trim());

  Future<PreparedTransfer> prepareTransfer({
    required Account account,
    required Keypair signer,
    required String recipient,
    required BigInt amount,
  }) async {
    await verifyMainnet();
    if (amount <= BigInt.zero) throw const FormatException('金额必须大于 0');
    if (!isValidAddress(recipient)) throw const FormatException('收款地址无效或不是 Quantus qz 地址');
    if (recipient.trim() == account.accountId) throw const FormatException('不能转账给当前地址');

    final normalizedRecipient = recipient.trim();
    final balance = await _substrate.queryBalance(account.accountId);
    final signed = await _substrate.getExtrinsicPayloadWithKeypair(
      account,
      BalancesService().getBalanceTransferCall(normalizedRecipient, amount),
      signer,
    );
    final fee = await _substrate.getFee(signed.payload);
    if (balance < amount + fee) {
      throw StateError('余额不足以支付金额和网络手续费');
    }

    return PreparedTransfer(
      payload: signed.payload,
      recipient: normalizedRecipient,
      amount: amount,
      fee: fee,
    );
  }

  Future<TransferReceipt> submitPreparedTransfer(PreparedTransfer prepared) async {
    if (DateTime.now().difference(prepared.createdAt) > const Duration(minutes: 2)) {
      throw StateError('交易确认已超时，请重新检查金额和手续费');
    }
    // Recheck the fail-closed network guard immediately before broadcasting.
    await verifyMainnet();

    final hashBytes = await _substrate.submitSignedExtrinsic(prepared.payload);
    return TransferReceipt(hash: '0x${hex.encode(hashBytes)}', fee: prepared.fee);
  }
}
