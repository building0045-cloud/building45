import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/apartment.dart';
import '../data/apartment_repository.dart';

sealed class ApartmentsState extends Equatable {
  const ApartmentsState();

  @override
  List<Object?> get props => [];
}

final class ApartmentsLoading extends ApartmentsState {
  const ApartmentsLoading();
}

final class ApartmentsLoaded extends ApartmentsState {
  const ApartmentsLoaded(this.apartments);
  final List<Apartment> apartments;

  Apartment? byId(String id) {
    for (final a in apartments) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  List<Object?> get props => [apartments];
}

final class ApartmentsFailure extends ApartmentsState {
  const ApartmentsFailure();
}

class ApartmentsCubit extends Cubit<ApartmentsState> {
  ApartmentsCubit(this._repo) : super(const ApartmentsLoading()) {
    _sub = _repo.watchAll().listen(
      (list) => emit(ApartmentsLoaded(list)),
      onError: (_) => emit(const ApartmentsFailure()),
    );
  }

  final ApartmentRepository _repo;
  late final StreamSubscription<List<Apartment>> _sub;

  Future<void> save({
    required Apartment before,
    required Apartment after,
    required String byUid,
  }) => _repo.save(before: before, after: after, byUid: byUid);

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
