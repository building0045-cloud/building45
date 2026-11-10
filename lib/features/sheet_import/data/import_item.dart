import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../core/building_refs.dart';

/// What a spreadsheet cell looks like. Only a proposal: nothing here is a
/// financial record until an admin confirms it.
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
    required this.apartmentNumber,
    required this.kind,
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
    apartmentNumber: (map['apartmentNumber'] as num?)?.toInt(),
    kind: ImportKind.parse(map['proposedKind']),
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
  final String originalText;
  final int? apartmentNumber;
  final ImportKind kind;
  final String status;

  /// The cell's value when it is a plain number, else null.
  num? get amount => num.tryParse(originalText.trim());

  @override
  List<Object?> get props => [id, originalText, kind, status];
}

class ImportRepository {
  ImportRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  Stream<List<ImportItem>> watchAll() => _refs.building
      .collection('importItems')
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs) ImportItem.fromMap(d.id, d.data()),
        ],
      );
}
