// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:substrate_metadata/substrate_metadata.dart';

const endpoint = 'https://rpc1-mainnet.quantus.com';
const expectedGenesis = '0xfb5487c0be6ae4ade2d41d16e50465129861636c2b8d61fa94d7a19631626fba';
const expectedSpecVersion = 152;
const expectedTransactionVersion = 6;
const expectedBalancesIndex = 2;
const expectedTransferAllowDeathIndex = 0;

Future<dynamic> rpc(HttpClient client, String method, [List<dynamic> params = const []]) async {
  final request = await client.postUrl(Uri.parse(endpoint));
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}));
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  if (response.statusCode != HttpStatus.ok) {
    throw StateError('$method returned HTTP ${response.statusCode}');
  }
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  if (decoded['error'] != null) throw StateError('$method: ${decoded['error']}');
  return decoded['result'];
}

Future<void> main() async {
  final client = HttpClient();
  try {
    final genesis = (await rpc(client, 'chain_getBlockHash', [0])).toString().toLowerCase();
    final runtime = await rpc(client, 'state_getRuntimeVersion') as Map<String, dynamic>;
    final metadataHex = (await rpc(client, 'state_getMetadata')).toString();
    final metadata = RuntimeMetadataPrefixed.fromHex(metadataHex).metadata;

    final balances = metadata.pallets.singleWhere((pallet) => pallet.name == 'Balances');
    final callType = metadata.typeById(balances.calls!.type).type.typeDef;
    if (callType is! TypeDefVariant) throw StateError('Balances calls are not a SCALE variant');
    final transfer = callType.variants.singleWhere((variant) => variant.name == 'transfer_allow_death');

    final observed = {
      'genesis': genesis,
      'specVersion': runtime['specVersion'],
      'transactionVersion': runtime['transactionVersion'],
      'metadataVersion': metadata.runtimeMetadataVersion(),
      'balancesIndex': balances.index,
      'transferAllowDeathIndex': transfer.index,
    };
    print(const JsonEncoder.withIndent('  ').convert(observed));

    if (genesis != expectedGenesis ||
        runtime['specVersion'] != expectedSpecVersion ||
        runtime['transactionVersion'] != expectedTransactionVersion ||
        balances.index != expectedBalancesIndex ||
        transfer.index != expectedTransferAllowDeathIndex) {
      throw StateError('Live mainnet metadata does not match this wallet build');
    }
    print('Mainnet metadata matches the wallet encoding.');
  } finally {
    client.close(force: true);
  }
}
