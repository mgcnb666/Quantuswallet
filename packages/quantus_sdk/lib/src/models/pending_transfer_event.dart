import 'package:quantus_sdk/quantus_sdk.dart';

class PendingTransactionEvent extends TransactionEvent {
  TransactionState transactionState;
  final bool isReversible;
  String? txId; // Nullable, set later for reversible
  final ReversibleTransferStatus? status; // Optional, for reversible
  DateTime? scheduledAtTime;
  int delaySeconds;
  BigInt? fee; // Optional, for transfers
  String? error;

  DateTime get scheduledAt => scheduledAtTime ?? DateTime.now();
  bool get isScheduled => isReversible;

  PendingTransactionEvent({
    required String tempId, // Generate temp ID at creation
    required super.from,
    required super.to,
    required super.amount,
    required super.timestamp,
    super.blockHash,
    this.transactionState = TransactionState.created,
    this.isReversible = false,
    this.txId,
    this.status = ReversibleTransferStatus.SCHEDULED,
    this.delaySeconds = 0,
    this.scheduledAtTime, // Set optimistically if reversible
    required this.fee,
    super.extrinsicHash,
    super.blockNumber = 0, // Initial 0, update on inclusion
    this.error,
  }) : super(id: tempId);

  factory PendingTransactionEvent.fromJson(Map<String, dynamic> json) {
    return PendingTransactionEvent(
      tempId: json['id'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      amount: BigInt.parse(json['amount'] as String),
      timestamp: DateTime.parse(json['timestamp']),
      blockHash: json['blockHash'] as String?,
      transactionState: TransactionState.values.firstWhere(
        (e) => e.name == json['transactionState'],
        orElse: () => TransactionState.pending,
      ),
      isReversible: json['isReversible'] ?? false,
      txId: json['txId'] as String?,
      status: ReversibleTransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReversibleTransferStatus.SCHEDULED,
      ),
      scheduledAtTime: json['scheduledAtTime'] != null ? DateTime.tryParse(json['scheduledAtTime']) : null,
      delaySeconds: json['delaySeconds'] ?? 0,
      fee: json['fee'] != null ? BigInt.parse(json['fee'] as String) : null,
      extrinsicHash: json['extrinsicHash'] as String?,
      blockNumber: json['blockNumber'] ?? 0,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': EventType.PENDING_TRANSACTION.name,
      'from': from,
      'to': to,
      'amount': amount.toString(),
      'timestamp': timestamp.toIso8601String(),
      'blockHash': blockHash,
      'transactionState': transactionState.name,
      'isReversible': isReversible,
      'txId': txId,
      'status': status?.name,
      'scheduledAtTime': scheduledAtTime?.toIso8601String(),
      'delaySeconds': delaySeconds,
      'fee': fee?.toString(),
      'extrinsicHash': extrinsicHash,
      'blockNumber': blockNumber,
      'error': error,
    };
  }

  @override
  String toString() {
    return 'PendingTransactionEvent{id: $id, from: $from, to: $to, '
        'amount: $amount, timestamp: $timestamp, state: $transactionState, '
        'isReversible: $isReversible, txId: $txId, status: $status, '
        'scheduledAt: $scheduledAt, delaySeconds: $delaySeconds, fee: $fee, '
        'extrinsicHash: $extrinsicHash, blockNumber: $blockNumber, '
        'error: $error}';
  }

  PendingTransactionEvent copyWith({
    String? id,
    String? from,
    String? to,
    BigInt? amount,
    DateTime? timestamp,
    String? blockHash,
    TransactionState? transactionState,
    int? delaySeconds,
    bool? isReversible,
    String? txId,
    ReversibleTransferStatus? status,
    DateTime? scheduledAtTime,
    BigInt? fee,
    String? extrinsicHash,
    int? blockNumber,
    String? error,
  }) {
    return PendingTransactionEvent(
      tempId: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      blockHash: blockHash ?? this.blockHash,
      transactionState: transactionState ?? this.transactionState,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      isReversible: isReversible ?? this.isReversible,
      txId: txId ?? this.txId,
      status: status ?? this.status,
      scheduledAtTime: scheduledAtTime ?? this.scheduledAtTime,
      fee: fee ?? this.fee,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
      blockNumber: blockNumber ?? this.blockNumber,
      error: error ?? this.error,
    );
  }
}
