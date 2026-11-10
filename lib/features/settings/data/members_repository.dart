import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/building_refs.dart';
import '../../auth/data/member.dart';

/// Staff accounts and pending access requests. Admin only.
class MembersRepository {
  MembersRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  Stream<String> watchBuildingName() =>
      _refs.building.snapshots().map((s) => s.data()?['name'] as String? ?? '');

  Stream<List<Member>> watchMembers() => _refs.members.snapshots().map(
    (snap) => [for (final d in snap.docs) Member.fromMap(d.id, d.data())],
  );

  Stream<List<AccessRequest>> watchRequests() =>
      _refs.accessRequests.snapshots().map(
        (snap) => [
          for (final d in snap.docs) AccessRequest.fromMap(d.id, d.data()),
        ],
      );

  Future<void> approve(
    AccessRequest request,
    MemberRole role, {
    required String byUid,
  }) {
    final member = Member(
      uid: request.uid,
      name: request.name,
      email: request.email,
      role: role,
      active: true,
    );
    final batch = _refs.db.batch()
      ..set(_refs.members.doc(request.uid), member.toMap())
      ..delete(_refs.accessRequests.doc(request.uid));
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'member.approve',
      target: _refs.members.doc(request.uid).path,
      summary: 'إضافة ${request.name} بصلاحية ${role.label}',
      after: member.toMap(),
    );
    return batch.commit();
  }

  Future<void> reject(AccessRequest request, {required String byUid}) {
    final batch = _refs.db.batch()
      ..delete(_refs.accessRequests.doc(request.uid));
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'member.reject',
      target: _refs.accessRequests.doc(request.uid).path,
      summary: 'رفض طلب ${request.name} (${request.email})',
    );
    return batch.commit();
  }

  Future<void> update(Member before, Member after, {required String byUid}) {
    final ref = _refs.members.doc(after.uid);
    final batch = _refs.db.batch()..set(ref, after.toMap());
    _refs.addAudit(
      batch,
      by: byUid,
      action: 'member.update',
      target: ref.path,
      summary: 'تعديل صلاحية ${after.name}',
      before: before.toMap(),
      after: after.toMap(),
    );
    return batch.commit();
  }
}
