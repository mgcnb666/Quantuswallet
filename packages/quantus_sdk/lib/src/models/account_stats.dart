import 'package:flutter/foundation.dart';

@immutable
class AccountStats {
  final int referralCount;
  final int sendCount;
  final int reversalCount;
  final int miningCount;
  final BigInt miningRewards;

  const AccountStats({
    required this.referralCount,
    required this.sendCount,
    required this.reversalCount,
    required this.miningCount,
    required this.miningRewards,
  });

  factory AccountStats.fromJson(Map<String, dynamic> json) {
    return AccountStats(
      referralCount: json['data']['referrals'] as int,
      sendCount: json['data']['immediate_txs'] as int,
      reversalCount: json['data']['reversible_txs'] as int,
      miningCount: json['data']['mining_events'] as int,
      miningRewards: BigInt.parse(json['data']['mining_rewards'] as String),
    );
  }
}
