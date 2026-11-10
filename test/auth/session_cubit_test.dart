import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/auth/cubit/session_cubit.dart';
import 'package:home_system/features/auth/data/auth_repository.dart';
import 'package:home_system/features/auth/data/member.dart';

class _FakeAuthRepository implements AuthRepository {
  final users = StreamController<AuthUser?>();
  final members = StreamController<Member?>();
  bool building = true;
  bool requested = false;

  @override
  Stream<AuthUser?> get userChanges => users.stream;

  @override
  Stream<Member?> watchMember(String uid) => members.stream;

  @override
  Future<bool> buildingExists() async => building;

  @override
  Future<bool> hasAccessRequest(String uid) async => requested;

  @override
  Future<void> requestAccess({
    required AuthUser user,
    required String name,
  }) async => requested = true;

  @override
  Future<void> setupBuilding({
    required AuthUser user,
    required String buildingName,
    required String adminName,
  }) async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

const _user = AuthUser(uid: 'u1', email: 'a@example.com');

Member _member({MemberRole role = MemberRole.treasurer, bool active = true}) =>
    Member(
      uid: 'u1',
      name: 'أمين',
      email: 'a@example.com',
      role: role,
      active: active,
    );

void main() {
  late _FakeAuthRepository repo;
  late SessionCubit cubit;

  setUp(() {
    repo = _FakeAuthRepository();
    cubit = SessionCubit(repo);
  });

  tearDown(() => cubit.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('signed out when there is no account', () async {
    repo.users.add(null);
    await settle();

    expect(cubit.state, const SessionSignedOut());
  });

  test('active for an active staff member', () async {
    repo.users.add(_user);
    repo.members.add(_member());
    await settle();

    expect(cubit.state, SessionActive(_user, _member()));
  });

  test('needs setup when no building exists', () async {
    repo.building = false;
    repo.users.add(_user);
    repo.members.add(null);
    await settle();

    expect(cubit.state, const SessionNeedsSetup(_user));
  });

  test('no access for an account that is not a member', () async {
    repo.users.add(_user);
    repo.members.add(null);
    await settle();

    expect(
      cubit.state,
      const SessionNoAccess(_user, requested: false, deactivated: false),
    );

    await cubit.requestAccess('اسم');

    expect(
      cubit.state,
      const SessionNoAccess(_user, requested: true, deactivated: false),
    );
  });

  test('no access for deactivated staff and for residents', () async {
    repo.users.add(_user);
    repo.members.add(_member(active: false));
    await settle();

    expect(
      cubit.state,
      const SessionNoAccess(_user, requested: false, deactivated: true),
    );

    repo.members.add(_member(role: MemberRole.resident));
    await settle();

    expect(cubit.state, isA<SessionNoAccess>());
  });
}
