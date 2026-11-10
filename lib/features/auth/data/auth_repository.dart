import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/building_refs.dart';
import 'member.dart';

/// Number of apartment rows created when the building is first set up.
const int initialApartmentCount = 24;

abstract class AuthRepository {
  Stream<AuthUser?> get userChanges;
  Stream<Member?> watchMember(String uid);
  Future<bool> buildingExists();
  Future<bool> hasAccessRequest(String uid);
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
  Future<void> setupBuilding({
    required AuthUser user,
    required String buildingName,
    required String adminName,
  });
  Future<void> requestAccess({required AuthUser user, required String name});
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, FirebaseFirestore db)
    : _refs = BuildingRefs(db);

  final FirebaseAuth _auth;
  final BuildingRefs _refs;

  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(
    (u) => u == null ? null : AuthUser(uid: u.uid, email: u.email ?? ''),
  );

  @override
  Stream<Member?> watchMember(String uid) => _refs.members
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? Member.fromMap(s.id, s.data()!) : null);

  @override
  Future<bool> buildingExists() async => (await _refs.building.get()).exists;

  @override
  Future<bool> hasAccessRequest(String uid) async =>
      (await _refs.accessRequests.doc(uid).get()).exists;

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> setupBuilding({
    required AuthUser user,
    required String buildingName,
    required String adminName,
  }) async {
    // The building document must exist before the rules let its owner
    // create the first admin membership.
    await _refs.building.set({
      'name': buildingName,
      'ownerUid': user.uid,
      'currency': 'EGP',
      'timeZone': 'Africa/Cairo',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _refs.members
        .doc(user.uid)
        .set(
          Member(
            uid: user.uid,
            name: adminName,
            email: user.email,
            role: MemberRole.admin,
            active: true,
          ).toMap(),
        );

    final batch = _refs.db.batch();
    for (var n = 1; n <= initialApartmentCount; n++) {
      batch.set(_refs.apartments.doc('$n'), {
        'number': n,
        'status': 'unknown',
        'feeEligible': true,
        'notes': '',
        'contacts': <JsonMap>[],
      });
    }
    _refs.addAudit(
      batch,
      by: user.uid,
      action: 'building.setup',
      target: _refs.building.path,
      summary: 'تهيئة العمارة وإنشاء $initialApartmentCount شقة',
    );
    await batch.commit();
  }

  @override
  Future<void> requestAccess({required AuthUser user, required String name}) =>
      _refs.accessRequests.doc(user.uid).set({
        'name': name,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

/// Arabic message for a failed sign-in or sign-up.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد مسجل بالفعل، جرّب تسجيل الدخول';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (٦ أحرف على الأقل)';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول بعد قليل';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت';
    }
  }
  return 'حدث خطأ غير متوقع، حاول مرة أخرى';
}
