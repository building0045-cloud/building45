import 'package:cloud_firestore/cloud_firestore.dart';

/// The single building served by this deployment. All data lives under
/// `buildings/{buildingId}` so more buildings can be added later.
const String buildingId = 'b45';

typedef JsonMap = Map<String, dynamic>;

class BuildingRefs {
  BuildingRefs(this.db);

  final FirebaseFirestore db;

  DocumentReference<JsonMap> get building =>
      db.collection('buildings').doc(buildingId);

  CollectionReference<JsonMap> get members => building.collection('members');

  CollectionReference<JsonMap> get accessRequests =>
      building.collection('accessRequests');

  CollectionReference<JsonMap> get apartments =>
      building.collection('apartments');

  CollectionReference<JsonMap> get auditLog => building.collection('auditLog');

  /// Adds an append-only audit entry to [batch].
  void addAudit(
    WriteBatch batch, {
    required String by,
    required String action,
    required String target,
    required String summary,
    JsonMap? before,
    JsonMap? after,
  }) {
    batch.set(auditLog.doc(), {
      'at': FieldValue.serverTimestamp(),
      'by': by,
      'action': action,
      'target': target,
      'summary': summary,
      'before': ?before,
      'after': ?after,
    });
  }
}
