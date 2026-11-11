import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/building_refs.dart';
import '../../../core/money.dart';
import '../../../core/periods.dart';
import '../../subscriptions/data/arrears.dart';
import '../../subscriptions/data/collection_message.dart';
import 'ledger_tx.dart';

/// Default monthly subscription: 100 EGP.
const defaultMonthlyFee = 10000;

/// Id used when a single month is collected with the check button.
String subscriptionTxId(String period, int apartmentNumber) =>
    'sub_${period}_$apartmentNumber';

String lockId(String period, int apartmentNumber) =>
    '${period}_$apartmentNumber';

/// Arabic description of the months a payment covers.
String describeMonths(List<String> periods) {
  if (periods.isEmpty) return '';
  if (periods.length == 1) return periodLabel(periods.first);
  final first = periodLabel(periods.first);
  final last = periodLabel(periods.last);
  final count = periods.length == 2
      ? 'شهرين'
      : '${toArabicDigits('${periods.length}')} شهور';
  return '$count ($first – $last)';
}

/// A month is already paid by another payment.
class MonthAlreadyPaid implements Exception {
  const MonthAlreadyPaid();
}

class LedgerRepository {
  LedgerRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  CollectionReference<JsonMap> get _tx =>
      _refs.building.collection('transactions');

  /// One document per apartment and month while a payment covers it, so the
  /// same month can never be paid twice.
  CollectionReference<JsonMap> get _locks =>
      _refs.building.collection('subscriptionLocks');
  DocumentReference<JsonMap> get _fees =>
      _refs.building.collection('settings').doc('fees');

  /// New document id, generated before saving so a double tap writes once.
  String newId() => _tx.doc().id;

  Stream<List<LedgerTx>> watchAll() => _tx
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) LedgerTx.fromMap(d.id, d.data())]);

  Stream<int> watchMonthlyFee() => _fees.snapshots().map(
    (s) => (s.data()?['monthlyFee'] as num?)?.toInt() ?? defaultMonthlyFee,
  );

  Future<void> setMonthlyFee(int piastres, {required String byUid}) {
    final batch = _refs.db.batch()
      ..set(_fees, {'monthlyFee': piastres}, SetOptions(merge: true));
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'settings.monthlyFee',
      target: _fees.path,
      summary: 'تغيير الاشتراك الشهري إلى ${formatEgp(piastres)}',
      after: {'monthlyFee': piastres},
    );
    return batch.commit();
  }

  DocumentReference<JsonMap> get _collectionMessage =>
      _refs.building.collection('settings').doc('collectionMessage');

  DocumentReference<JsonMap> _yearClose(int year) =>
      _refs.building.collection('settings').doc('yearClose_$year');

  Stream<CollectionTemplate> watchCollectionTemplate() => _collectionMessage
      .snapshots()
      .map((s) => CollectionTemplate.fromMap(s.data()));

  Future<void> saveCollectionTemplate(
    CollectionTemplate template, {
    required String byUid,
  }) {
    final batch = _refs.db.batch()..set(_collectionMessage, template.toMap());
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'settings.collectionMessage',
      target: _collectionMessage.path,
      summary: 'تعديل نص رسالة التحصيل',
      after: template.toMap(),
    );
    return batch.commit();
  }

  /// When [year] was closed, or null if it was not.
  Stream<DateTime?> watchYearClose(int year) =>
      _yearClose(year)
          .snapshots()
          .map((s) => (s.data()?['closedAt'] as Timestamp?)?.toDate());

  /// Saves what each apartment still owed for [year] as a record. The
  /// live arrears keep counting those months until they are paid.
  Future<void> closeYear(int year, Arrears arrears, {required String byUid}) {
    final apartments = <String, dynamic>{
      for (final n in arrears.byApartment.keys)
        if (arrears.monthsFor(n).any((m) => periodYear(m.period) <= year))
          '$n': {
            'owed': [
              for (final m in arrears.monthsFor(n))
                if (periodYear(m.period) <= year) m.owed,
            ].fold(0, (s, v) => s + v),
            'months': [
              for (final m in arrears.monthsFor(n))
                if (periodYear(m.period) <= year)
                  {'period': m.period, 'owed': m.owed},
            ],
          },
    };
    final total = [for (final a in apartments.values) (a as Map)['owed'] as int]
        .fold(0, (s, v) => s + v);
    final ref = _yearClose(year);
    final batch = _refs.db.batch()
      ..set(ref, {
        'year': year,
        'closedAt': FieldValue.serverTimestamp(),
        'byUid': byUid,
        'total': total,
        'apartments': apartments,
      });
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'subscriptions.closeYear',
      target: ref.path,
      summary:
          'إقفال سنة ${toArabicDigits('$year')}: متأخرات ${formatEgp(total)} '
          'تُرحَّل للسنة التالية',
    );
    return batch.commit();
  }

  Future<void> addExpense({
    required String id,
    required int amount,
    required ExpenseCategory category,
    required String description,
    required DateTime date,
    required String byUid,
    String byName = '',
  }) {
    final tx = LedgerTx(
      id: id,
      type: TxType.expense,
      amount: amount,
      date: date,
      description: description,
      category: category,
      createdBy: byUid,
      createdByName: byName,
    );
    final ref = _tx.doc(id);
    final batch = _refs.db.batch()
      ..set(ref, {...tx.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'expense.add',
      target: ref.path,
      summary: 'مصروف ${formatEgp(amount)}: ${tx.title}',
    );
    return batch.commit();
  }

  /// An apartment's contribution to a project. One entry per apartment and
  /// project, so a contribution cannot be counted twice.
  Future<void> recordProjectPayment({
    required String projectId,
    required String projectName,
    required int apartmentNumber,
    required int amount,
    required String byUid,
    String byName = '',
  }) {
    final tx = LedgerTx(
      id: 'prj_${projectId}_$apartmentNumber',
      type: TxType.project,
      amount: amount,
      date: DateTime.now(),
      description: 'مساهمة $projectName - شقة $apartmentNumber',
      apartmentNumber: apartmentNumber,
      projectId: projectId,
      createdBy: byUid,
      createdByName: byName,
    );
    final ref = _tx.doc(tx.id);
    final batch = _refs.db.batch()
      ..set(ref, {...tx.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'project.collect',
      target: ref.path,
      summary: 'تحصيل ${tx.description}: ${formatEgp(amount)}',
    );
    return batch.commit();
  }

  /// One-tap collection of a single month.
  Future<void> recordSubscription({
    required String period,
    required int apartmentNumber,
    required int amount,
    required String byUid,
    String byName = '',
  }) => savePayment(
    id: subscriptionTxId(period, apartmentNumber),
    apartmentNumber: apartmentNumber,
    allocations: [Allocation(period, amount)],
    date: DateTime.now(),
    byUid: byUid,
    byName: byName,
  );

  /// Records (or, with [previous], replaces) a subscription payment that
  /// covers one or more months. Throws [MonthAlreadyPaid] when a month is
  /// covered by another payment.
  Future<void> savePayment({
    required String id,
    required int apartmentNumber,
    required List<Allocation> allocations,
    required DateTime date,
    required String byUid,
    String byName = '',
    String payerName = '',
    String payerKind = '',
    LedgerTx? previous,
  }) async {
    final periods = [for (final a in allocations) a.period];
    final total = allocations.fold(0, (s, a) => s + a.amount);
    final payer = payerName.isEmpty ? '' : ' من $payerName';
    final tx = LedgerTx(
      id: id,
      type: TxType.subscription,
      amount: total,
      date: date,
      description:
          'اشتراك ${describeMonths(periods)} - شقة $apartmentNumber$payer',
      apartmentNumber: apartmentNumber,
      allocations: allocations,
      payerName: payerName,
      payerKind: payerKind,
      createdBy: previous?.createdBy.isNotEmpty == true
          ? previous!.createdBy
          : byUid,
      // Editing keeps the person who originally collected the money.
      createdByName: previous != null && previous.createdBy.isNotEmpty
          ? previous.createdByName
          : byName,
    );
    final ref = _tx.doc(id);
    final before = previous != null && !previous.voided
        ? previous.periods.toSet()
        : <String>{};
    final batch = _refs.db.batch()
      ..set(ref, {
        ...tx.toMap(),
        if (previous == null) 'createdAt': FieldValue.serverTimestamp(),
        if (previous != null) 'editedBy': byUid,
        if (previous != null) 'editedAt': FieldValue.serverTimestamp(),
      });
    for (final p in periods.where((p) => !before.contains(p))) {
      batch.set(_locks.doc(lockId(p, apartmentNumber)), {
        'period': p,
        'apartmentNumber': apartmentNumber,
        'txId': id,
      });
    }
    for (final p in before.where((p) => !periods.contains(p))) {
      batch.delete(_locks.doc(lockId(p, apartmentNumber)));
    }
    _refs.addAudit(
      batch,
      by: byUid,
      action: previous == null ? 'subscription.collect' : 'subscription.edit',
      target: ref.path,
      summary:
          '${previous == null ? 'تحصيل' : 'تعديل'} ${tx.description}: ${formatEgp(total)}',
      before: previous == null
          ? null
          : {'amount': previous.amount, 'periods': previous.periods},
      after: {'amount': total, 'periods': periods},
    );
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // A lock that already exists cannot be created again.
      if (e.code == 'permission-denied') throw const MonthAlreadyPaid();
      rethrow;
    }
  }

  Future<void> updateAmount(LedgerTx tx, int amount, {required String byUid}) {
    final ref = _tx.doc(tx.id);
    final batch = _refs.db.batch()
      ..update(ref, {
        'amount': amount,
        'editedBy': byUid,
        'editedAt': FieldValue.serverTimestamp(),
      });
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'tx.amount',
      target: ref.path,
      summary:
          'تعديل مبلغ "${tx.title}" من ${formatEgp(tx.amount)} إلى ${formatEgp(amount)}',
      before: {'amount': tx.amount},
      after: {'amount': amount},
    );
    return batch.commit();
  }

  /// Cancels (or restores) an entry. It stays in the log either way; the
  /// months of a cancelled subscription payment become unpaid again.
  Future<void> setVoided(
    LedgerTx tx,
    bool voided, {
    required String byUid,
  }) async {
    final ref = _tx.doc(tx.id);
    final batch = _refs.db.batch()
      ..update(ref, {
        'voided': voided,
        'editedBy': byUid,
        'editedAt': FieldValue.serverTimestamp(),
      });
    if (tx.type == TxType.subscription && tx.apartmentNumber != null) {
      for (final p in tx.periods) {
        final lock = _locks.doc(lockId(p, tx.apartmentNumber!));
        if (voided) {
          batch.delete(lock);
        } else {
          batch.set(lock, {
            'period': p,
            'apartmentNumber': tx.apartmentNumber,
            'txId': tx.id,
          });
        }
      }
    }
    _refs.addAudit(
      batch,
      by: byUid,
      action: voided ? 'tx.void' : 'tx.restore',
      target: ref.path,
      summary:
          '${voided ? 'إلغاء' : 'استرجاع'} "${tx.title}" (${formatEgp(tx.amount)})',
      before: {'voided': tx.voided},
      after: {'voided': voided},
    );
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (!voided && e.code == 'permission-denied') {
        throw const MonthAlreadyPaid();
      }
      rethrow;
    }
  }
}
