import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/building_refs.dart';

enum TxType {
  opening('رصيد افتتاحي'),
  income('إيراد'),
  subscription('اشتراك شهري'),
  project('مساهمة مشروع'),
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

/// The share of a subscription payment that covers one month.
class Allocation extends Equatable {
  const Allocation(this.period, this.amount);

  factory Allocation.fromMap(Map<String, dynamic> m) =>
      Allocation(m['period'] as String, (m['amount'] as num).toInt());

  /// `yyyy-MM`.
  final String period;

  /// Piastres.
  final int amount;

  Map<String, dynamic> toMap() => {'period': period, 'amount': amount};

  @override
  List<Object?> get props => [period, amount];
}

/// One money movement. Amounts are positive whole piastres; the type
/// decides whether it adds to or takes from the balance.
///
/// A subscription payment is recorded once, for its full amount, and its
/// [allocations] say which months it covers. Splitting it across months
/// never changes the balance.
class LedgerTx extends Equatable {
  const LedgerTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.category,
    this.apartmentNumber,
    this.allocations = const [],
    this.payerName = '',
    this.payerKind = '',
    this.projectId,
    this.voided = false,
    this.createdBy = '',
    this.createdByName = '',
  });

  factory LedgerTx.fromMap(String id, JsonMap m) {
    final amount = (m['amount'] as num?)?.toInt() ?? 0;
    final legacyPeriod = m['period'] as String?;
    final raw = m['allocations'] as List<dynamic>?;
    return LedgerTx(
      id: id,
      type: TxType.parse(m['type']),
      amount: amount,
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: m['description'] as String? ?? '',
      category: ExpenseCategory.parse(m['category']),
      apartmentNumber: (m['apartmentNumber'] as num?)?.toInt(),
      allocations: raw != null
          ? [
              for (final a in raw)
                Allocation.fromMap(Map<String, dynamic>.from(a as Map)),
            ]
          : [if (legacyPeriod != null) Allocation(legacyPeriod, amount)],
      payerName: m['payerName'] as String? ?? '',
      payerKind: m['payerKind'] as String? ?? '',
      projectId: m['projectId'] as String?,
      voided: m['voided'] as bool? ?? false,
      createdBy: m['createdBy'] as String? ?? '',
      createdByName: m['createdByName'] as String? ?? '',
    );
  }

  final String id;
  final TxType type;
  final int amount;
  final DateTime date;
  final String description;
  final ExpenseCategory? category;
  final int? apartmentNumber;

  /// Months a subscription payment covers, in order.
  final List<Allocation> allocations;

  /// Who handed over the money (subscription payments).
  final String payerName;

  /// `owner`, `tenant` or empty.
  final String payerKind;

  /// Project a contribution belongs to.
  final String? projectId;

  /// Cancelled entries stay in the log but do not count.
  final bool voided;

  /// Staff member who recorded the entry: who collected the money or paid
  /// the expense.
  final String createdBy;
  final String createdByName;

  bool get isOutgoing => type == TxType.expense;

  List<String> get periods => [for (final a in allocations) a.period];

  /// Effect on the balance.
  int get signedAmount => voided ? 0 : (isOutgoing ? -amount : amount);

  IconData get icon => switch (type) {
    TxType.opening => Icons.account_balance_wallet_outlined,
    TxType.subscription =>
      allocations.length > 1 ? Icons.date_range_outlined : Icons.home_outlined,
    TxType.income => Icons.south_west,
    TxType.project => Icons.savings_outlined,
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
    'apartmentNumber': apartmentNumber,
    if (type == TxType.subscription) ...{
      'allocations': [for (final a in allocations) a.toMap()],
      'periods': periods,
      'payerName': payerName,
      'payerKind': payerKind,
    },
    if (projectId != null) 'projectId': projectId,
    'voided': voided,
    'createdBy': createdBy,
    'createdByName': createdByName,
  };

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    date,
    description,
    category,
    apartmentNumber,
    allocations,
    payerName,
    payerKind,
    voided,
  ];
}

/// Sum of all entries that count.
int balanceOf(Iterable<LedgerTx> txs) =>
    txs.fold(0, (total, t) => total + t.signedAmount);

/// Splits [total] over [periods]: [fee] for each month in order, the last
/// month gets what is left. Returns null when [total] does not reach the
/// last month or exceeds [fee] for every month.
List<Allocation>? splitPayment(int total, List<String> periods, int fee) {
  if (periods.isEmpty || total <= 0) return null;
  final n = periods.length;
  if (total > n * fee || total <= (n - 1) * fee) return null;
  return [
    for (var i = 0; i < n; i++)
      Allocation(periods[i], i < n - 1 ? fee : total - (n - 1) * fee),
  ];
}
