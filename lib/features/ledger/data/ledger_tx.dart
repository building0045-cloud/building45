import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/building_refs.dart';

enum TxType {
  opening('رصيد افتتاحي'),
  income('إيراد'),
  subscription('اشتراك شهري'),
  expense('مصروف');

  const TxType(this.label);
  final String label;

  static TxType parse(Object? v) =>
      TxType.values.firstWhere((t) => t.name == v, orElse: () => TxType.income);
}

enum ExpenseCategory {
  cleaning('نظافة', Icons.cleaning_services_outlined),
  maintenance('صيانة', Icons.build_outlined),
  electricity('كهرباء وإنارة', Icons.lightbulb_outline),
  security('أمن وكاميرات', Icons.videocam_outlined),
  landscaping('زراعة وتشجير', Icons.park_outlined),
  other('أخرى', Icons.more_horiz);

  const ExpenseCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static ExpenseCategory? parse(Object? v) =>
      ExpenseCategory.values.where((c) => c.name == v).firstOrNull;
}

/// One money movement. Amounts are positive whole piastres; the type
/// decides whether it adds to or takes from the balance.
class LedgerTx extends Equatable {
  const LedgerTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.category,
    this.period,
    this.apartmentNumber,
    this.voided = false,
    this.createdBy = '',
  });

  factory LedgerTx.fromMap(String id, JsonMap m) => LedgerTx(
    id: id,
    type: TxType.parse(m['type']),
    amount: (m['amount'] as num?)?.toInt() ?? 0,
    date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    description: m['description'] as String? ?? '',
    category: ExpenseCategory.parse(m['category']),
    period: m['period'] as String?,
    apartmentNumber: (m['apartmentNumber'] as num?)?.toInt(),
    voided: m['voided'] as bool? ?? false,
    createdBy: m['createdBy'] as String? ?? '',
  );

  final String id;
  final TxType type;
  final int amount;
  final DateTime date;
  final String description;
  final ExpenseCategory? category;

  /// Month a subscription payment covers.
  final String? period;
  final int? apartmentNumber;

  /// Cancelled entries stay in the log but do not count.
  final bool voided;
  final String createdBy;

  bool get isOutgoing => type == TxType.expense;

  /// Effect on the balance.
  int get signedAmount => voided ? 0 : (isOutgoing ? -amount : amount);

  IconData get icon => switch (type) {
    TxType.opening => Icons.account_balance_wallet_outlined,
    TxType.subscription => Icons.home_outlined,
    TxType.income => Icons.south_west,
    TxType.expense => category?.icon ?? Icons.north_east,
  };

  String get title =>
      description.isNotEmpty ? description : (category?.label ?? type.label);

  JsonMap toMap() => {
    'type': type.name,
    'amount': amount,
    'date': Timestamp.fromDate(date),
    'description': description,
    'category': category?.name,
    'period': period,
    'apartmentNumber': apartmentNumber,
    'voided': voided,
    'createdBy': createdBy,
  };

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    date,
    description,
    category,
    period,
    apartmentNumber,
    voided,
  ];
}

/// Sum of all entries that count.
int balanceOf(Iterable<LedgerTx> txs) =>
    txs.fold(0, (total, t) => total + t.signedAmount);
