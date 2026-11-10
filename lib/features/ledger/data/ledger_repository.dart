import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/building_refs.dart';
import '../../../core/money.dart';
import '../../../core/periods.dart';
import 'ledger_tx.dart';

/// Default monthly subscription: 100 EGP.
const defaultMonthlyFee = 10000;

String subscriptionTxId(String period, int apartmentNumber) =>
    'sub_${period}_$apartmentNumber';

class LedgerRepository {
  LedgerRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  CollectionReference<JsonMap> get _tx =>
      _refs.building.collection('transactions');
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

  Future<void> addExpense({
    required String id,
    required int amount,
    required ExpenseCategory category,
    required String description,
    required DateTime date,
    required String byUid,
  }) {
    final tx = LedgerTx(
      id: id,
      type: TxType.expense,
      amount: amount,
      date: date,
      description: description,
      category: category,
      createdBy: byUid,
    );
    return _write(tx, 'expense.add', 'مصروف ${formatEgp(amount)}: ${tx.title}');
  }

  /// Records [apartmentNumber]'s subscription for [period]. The id is fixed
  /// per apartment and month, so the month can never be counted twice.
  Future<void> recordSubscription({
    required String period,
    required int apartmentNumber,
    required int amount,
    required String byUid,
  }) {
    final tx = LedgerTx(
      id: subscriptionTxId(period, apartmentNumber),
      type: TxType.subscription,
      amount: amount,
      date: DateTime.now(),
      description: 'اشتراك ${periodLabel(period)} - شقة $apartmentNumber',
      period: period,
      apartmentNumber: apartmentNumber,
      createdBy: byUid,
    );
    return _write(
      tx,
      'subscription.collect',
      'تحصيل ${tx.description}: ${formatEgp(amount)}',
    );
  }

  Future<void> _write(LedgerTx tx, String action, String summary) {
    final ref = _tx.doc(tx.id);
    final batch = _refs.db.batch()
      ..set(ref, {...tx.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    _refs.addAudit(
      batch,
      by: tx.createdBy,
      action: action,
      target: ref.path,
      summary: summary,
      after: tx.toMap()..remove('date'),
    );
    return batch.commit();
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

  /// Cancels (or restores) an entry. It stays in the log either way.
  Future<void> setVoided(LedgerTx tx, bool voided, {required String byUid}) {
    final ref = _tx.doc(tx.id);
    final batch = _refs.db.batch()
      ..update(ref, {
        'voided': voided,
        'editedBy': byUid,
        'editedAt': FieldValue.serverTimestamp(),
      });
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
    return batch.commit();
  }
}
