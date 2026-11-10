import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../data/member.dart';

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

final class SessionLoading extends SessionState {
  const SessionLoading();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// Signed in, and no building has been set up yet.
final class SessionNeedsSetup extends SessionState {
  const SessionNeedsSetup(this.user);
  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// Signed in, but not an active staff member of the building.
final class SessionNoAccess extends SessionState {
  const SessionNoAccess(
    this.user, {
    required this.requested,
    required this.deactivated,
  });
  final AuthUser user;
  final bool requested;
  final bool deactivated;

  @override
  List<Object?> get props => [user, requested, deactivated];
}

final class SessionActive extends SessionState {
  const SessionActive(this.user, this.member);
  final AuthUser user;
  final Member member;

  @override
  List<Object?> get props => [user, member];
}

final class SessionFailure extends SessionState {
  const SessionFailure();
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repo) : super(const SessionLoading()) {
    _userSub = _repo.userChanges.listen(_onUser);
  }

  final AuthRepository _repo;
  late final StreamSubscription<AuthUser?> _userSub;
  StreamSubscription<Member?>? _memberSub;

  void _onUser(AuthUser? user) {
    _memberSub?.cancel();
    _memberSub = null;
    if (user == null) {
      emit(const SessionSignedOut());
      return;
    }
    emit(const SessionLoading());
    _memberSub = _repo
        .watchMember(user.uid)
        .listen(
          (member) => _onMember(user, member),
          onError: (_) => emit(const SessionFailure()),
        );
  }

  Future<void> _onMember(AuthUser user, Member? member) async {
    if (member != null && member.isStaff) {
      emit(SessionActive(user, member));
      return;
    }
    try {
      if (!await _repo.buildingExists()) {
        emit(SessionNeedsSetup(user));
        return;
      }
      final requested = await _repo.hasAccessRequest(user.uid);
      emit(
        SessionNoAccess(
          user,
          requested: requested,
          deactivated: member != null && !member.active,
        ),
      );
    } catch (_) {
      emit(const SessionFailure());
    }
  }

  Future<void> setupBuilding({
    required String buildingName,
    required String adminName,
  }) async {
    final current = state;
    if (current is! SessionNeedsSetup) return;
    await _repo.setupBuilding(
      user: current.user,
      buildingName: buildingName,
      adminName: adminName,
    );
  }

  Future<void> requestAccess(String name) async {
    final current = state;
    if (current is! SessionNoAccess) return;
    await _repo.requestAccess(user: current.user, name: name);
    emit(SessionNoAccess(current.user, requested: true, deactivated: false));
  }

  Future<void> signOut() => _repo.signOut();

  @override
  Future<void> close() async {
    await _memberSub?.cancel();
    await _userSub.cancel();
    return super.close();
  }
}
