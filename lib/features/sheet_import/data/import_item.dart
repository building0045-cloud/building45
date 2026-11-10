import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../core/building_refs.dart';
import '../../../core/money.dart';

export '../../../core/money.dart' show parseAmount;

/// What a contribution record looks like. Imported records are proposals
/// taken from the old spreadsheet, not confirmed ledger entries.
enum ImportKind {
  payment('مبلغ مدفوع'),
  paymentReference('إشارة لدفعة في شهر آخر'),
  settledNote('«خالص» (يحتاج مراجعة)'),
  notHandedOverNote('لم يتسلم الوحدة'),
  rowNote('ملاحظة على الشقة'),
  total('إجمالي'),
  expenseCandidate('مصروف محتمل'),
  balanceNote('ملاحظة رصيد'),
  noteValue('رقم في الملاحظات'),
  note('ملاحظة');

  const ImportKind(this.label);
  final String label;

  static ImportKind parse(Object? value) => ImportKind.values.firstWhere(
    (k) => k.name == value,
    orElse: () => ImportKind.note,
  );
}

const settledText = 'خالص';
const notHandedOverText = 'لم يتسلم الوحده';
const paidInPrefix = 'تم الدفع في';

/// Kind of an apartment's contribution cell, from its text.
ImportKind classifyContribution(String text) {
  final t = text.trim();
  if (parseAmount(t) != null) return ImportKind.payment;
  if (t == settledText) return ImportKind.settledNote;
  if (t.startsWith(paidInPrefix)) return ImportKind.paymentReference;
  if (t == notHandedOverText) return ImportKind.notHandedOverNote;
  return ImportKind.note;
}

class ImportItem extends Equatable {
  const ImportItem({
    required this.id,
    required this.sheetGid,
    required this.sheetName,
    required this.period,
    required this.cell,
    required this.row,
    required this.col,
    required this.originalText,
    required this.editedText,
    required this.apartmentNumber,
    required this.originalKind,
    required this.status,
  });

  factory ImportItem.fromMap(String id, JsonMap map) => ImportItem(
    id: id,
    sheetGid: map['sheetGid'] as String? ?? '',
    sheetName: map['sheetName'] as String? ?? '',
    period: map['period'] as String?,
    cell: map['cell'] as String? ?? '',
    row: (map['row'] as num?)?.toInt() ?? 0,
    col: (map['col'] as num?)?.toInt() ?? 0,
    originalText: map['originalText'] as String? ?? '',
    editedText: map['editedText'] as String?,
    apartmentNumber: (map['apartmentNumber'] as num?)?.toInt(),
    originalKind: ImportKind.parse(map['proposedKind']),
    status: map['status'] as String? ?? 'pending',
  );

  final String id;
  final String sheetGid;
  final String sheetName;

  /// `yyyy-MM` for monthly sheets, null for project sheets.
  final String? period;
  final String cell;
  final int row;
  final int col;

  /// Exactly what the spreadsheet cell said; empty for records added here.
  final String originalText;

  /// Value entered in the app, replacing [originalText] for display and
  /// totals. The original is kept for traceability.
  final String? editedText;
  final int? apartmentNumber;
  final ImportKind originalKind;
  final String status;

  bool get isEdited => editedText != null;

  /// Current value: the edit when there is one, else the sheet's text.
  String get text => (editedText ?? originalText).trim();

  /// The apartment's contribution cell (third column of the sheet).
  bool get isContributionCell => apartmentNumber != null && col == 3;

  ImportKind get kind => isEdited && isContributionCell
      ? classifyContribution(text)
      : originalKind;

  /// The current value when it is a plain number, else null.
  num? get amount => parseAmount(text);

  @override
  List<Object?> get props => [
    id,
    originalText,
    editedText,
    originalKind,
    status,
  ];
}

class ImportRepository {
  ImportRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  CollectionReference<JsonMap> get _items =>
      _refs.building.collection('importItems');

  Stream<List<ImportItem>> watchAll() => _items.snapshots().map(
    (snap) => [for (final d in snap.docs) ImportItem.fromMap(d.id, d.data())],
  );

  /// Sets the contribution value of [apartmentNumber] in the sheet that
  /// [sheet] belongs to. Keeps the spreadsheet's original text and writes
  /// an audit entry. An empty [text] means "no record".
  Future<void> saveContribution({
    required ImportItem sheet,
    required ImportItem? existing,
    required int apartmentNumber,
    required String text,
    required String byUid,
  }) {
    // In every sheet apartment n is on row n + 1, amount in column C.
    final row = apartmentNumber + 1;
    final ref = _items.doc(existing?.id ?? '${sheet.sheetGid}_C$row');
    final before = existing?.text ?? '';
    final batch = _refs.db.batch()
      ..set(ref, {
        if (existing == null) ...{
          'sheetGid': sheet.sheetGid,
          'sheetName': sheet.sheetName,
          'sheetKind': sheet.period == null ? 'project' : 'monthly',
          'period': sheet.period,
          'cell': 'C$row',
          'row': row,
          'col': 3,
          'originalText': '',
          'apartmentNumber': apartmentNumber,
          'proposedKind': ImportKind.note.name,
          'status': 'pending',
          'source': 'manual',
        },
        'editedText': text.trim(),
        'editedBy': byUid,
        'editedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'contribution.edit',
      target: ref.path,
      summary: 'تعديل ${sheet.sheetName} لشقة $apartmentNumber',
      before: {'text': before},
      after: {'text': text.trim()},
    );
    return batch.commit();
  }

  /// Rewrites a note row (expense or balance text) of a sheet.
  Future<void> saveNote({
    required ImportItem item,
    required String text,
    required String byUid,
  }) {
    final ref = _items.doc(item.id);
    final batch = _refs.db.batch()
      ..set(ref, {
        'editedText': text.trim(),
        'editedBy': byUid,
        'editedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'sheetNote.edit',
      target: ref.path,
      summary: 'تعديل ملاحظة في ${item.sheetName}',
      before: {'text': item.text},
      after: {'text': text.trim()},
    );
    return batch.commit();
  }
}
