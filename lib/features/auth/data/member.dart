import 'package:equatable/equatable.dart';

import '../../../core/building_refs.dart';

enum MemberRole {
  admin('مدير'),
  treasurer('أمين صندوق'),
  resident('ساكن');

  const MemberRole(this.label);
  final String label;

  static MemberRole parse(Object? value) => MemberRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => MemberRole.resident,
  );
}

class Member extends Equatable {
  const Member({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  factory Member.fromMap(String uid, JsonMap map) => Member(
    uid: uid,
    name: map['name'] as String? ?? '',
    email: map['email'] as String? ?? '',
    role: MemberRole.parse(map['role']),
    active: map['active'] as bool? ?? false,
  );

  final String uid;
  final String name;
  final String email;
  final MemberRole role;
  final bool active;

  bool get isAdmin => active && role == MemberRole.admin;
  bool get isStaff =>
      active && (role == MemberRole.admin || role == MemberRole.treasurer);

  JsonMap toMap() => {
    'name': name,
    'email': email,
    'role': role.name,
    'active': active,
  };

  @override
  List<Object?> get props => [uid, name, email, role, active];
}

class AccessRequest extends Equatable {
  const AccessRequest({
    required this.uid,
    required this.name,
    required this.email,
  });

  factory AccessRequest.fromMap(String uid, JsonMap map) => AccessRequest(
    uid: uid,
    name: map['name'] as String? ?? '',
    email: map['email'] as String? ?? '',
  );

  final String uid;
  final String name;
  final String email;

  @override
  List<Object?> get props => [uid, name, email];
}

/// The signed-in Firebase account, independent of building membership.
class AuthUser extends Equatable {
  const AuthUser({required this.uid, required this.email});

  final String uid;
  final String email;

  @override
  List<Object?> get props => [uid, email];
}
