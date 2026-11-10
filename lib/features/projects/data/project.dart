import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/building_refs.dart';
import '../../../core/money.dart';

/// Icons an admin can pick for a project.
const projectIcons = <String, IconData>{
  'savings': Icons.savings_outlined,
  'camera': Icons.videocam_outlined,
  'fence': Icons.fence_outlined,
  'tree': Icons.park_outlined,
  'light': Icons.lightbulb_outline,
  'door': Icons.door_front_door_outlined,
  'paint': Icons.format_paint_outlined,
  'elevator': Icons.elevator_outlined,
  'water': Icons.water_drop_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'build': Icons.construction_outlined,
  'security': Icons.shield_outlined,
};

IconData projectIcon(String key) => projectIcons[key] ?? Icons.savings_outlined;

class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.icon,
    required this.total,
    required this.shares,
  });

  factory Project.fromMap(String id, JsonMap m) => Project(
    id: id,
    name: m['name'] as String? ?? '',
    icon: m['icon'] as String? ?? 'savings',
    total: (m['total'] as num?)?.toInt() ?? 0,
    shares: {
      for (final e in ((m['shares'] as Map?) ?? const {}).entries)
        int.parse('${e.key}'): (e.value as num).toInt(),
    },
  );

  final String id;
  final String name;
  final String icon;

  /// Target in piastres.
  final int total;

  /// Amount each participating apartment owes, by apartment number.
  final Map<int, int> shares;

  JsonMap toMap() => {
    'name': name,
    'icon': icon,
    'total': total,
    'shares': {for (final e in shares.entries) '${e.key}': e.value},
  };

  @override
  List<Object?> get props => [id, name, icon, total, shares];
}

/// Splits [total] equally over [apartments] in whole pounds; the first
/// apartments take the remaining pounds, and any piastres go to the first.
Map<int, int> splitEqually(int total, List<int> apartments) {
  if (apartments.isEmpty || total <= 0) return const {};
  final pounds = total ~/ 100;
  final piastres = total % 100;
  final base = pounds ~/ apartments.length;
  final extra = pounds % apartments.length;
  return {
    for (final (i, a) in apartments.indexed)
      a: (base + (i < extra ? 1 : 0)) * 100 + (i == 0 ? piastres : 0),
  };
}

class ProjectRepository {
  ProjectRepository(FirebaseFirestore db) : _refs = BuildingRefs(db);

  final BuildingRefs _refs;

  CollectionReference<JsonMap> get _projects =>
      _refs.building.collection('projects');

  String newId() => _projects.doc().id;

  Stream<List<Project>> watchAll() => _projects
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Project.fromMap(d.id, d.data())]);

  Future<void> save(
    Project project, {
    required String byUid,
    Project? previous,
  }) {
    final ref = _projects.doc(project.id);
    final batch = _refs.db.batch()
      ..set(ref, {
        ...project.toMap(),
        if (previous == null) 'createdAt': FieldValue.serverTimestamp(),
        if (previous == null) 'createdBy': byUid,
        if (previous != null) 'editedBy': byUid,
        if (previous != null) 'editedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    _refs.addAudit(
      batch,
      by: byUid,
      action: previous == null ? 'project.create' : 'project.edit',
      target: ref.path,
      summary:
          '${previous == null ? 'إنشاء' : 'تعديل'} مشروع ${project.name} بإجمالي ${formatEgp(project.total)}',
      before: previous?.toMap(),
      after: project.toMap(),
    );
    return batch.commit();
  }
}
