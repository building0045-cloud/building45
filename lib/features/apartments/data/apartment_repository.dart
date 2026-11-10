import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/building_refs.dart';
import 'apartment.dart';

abstract class ApartmentRepository {
  Stream<List<Apartment>> watchAll();
  Future<void> save({
    required Apartment before,
    required Apartment after,
    required String byUid,
  });
}

class FirestoreApartmentRepository implements ApartmentRepository {
  FirestoreApartmentRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  @override
  Stream<List<Apartment>> watchAll() => _refs.apartments
      .orderBy('number')
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs) Apartment.fromMap(d.id, d.data()),
        ],
      );

  @override
  Future<void> save({
    required Apartment before,
    required Apartment after,
    required String byUid,
  }) {
    final ref = _refs.apartments.doc(after.id);
    final batch = _refs.db.batch()..set(ref, after.toMap());
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'apartment.update',
      target: ref.path,
      summary: 'تعديل بيانات شقة ${after.number}',
      before: before.toMap(),
      after: after.toMap(),
    );
    return batch.commit();
  }
}
