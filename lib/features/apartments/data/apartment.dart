import 'package:equatable/equatable.dart';

import '../../../core/building_refs.dart';

enum ApartmentStatus {
  occupied('مسكونة'),
  vacant('خالية'),
  notHandedOver('لم تُسلَّم'),
  unknown('غير معروف');

  const ApartmentStatus(this.label);
  final String label;

  static ApartmentStatus parse(Object? value) =>
      ApartmentStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => ApartmentStatus.unknown,
      );
}

enum ContactKind {
  owner('مالك'),
  tenant('مستأجر');

  const ContactKind(this.label);
  final String label;

  static ContactKind parse(Object? value) => ContactKind.values.firstWhere(
    (k) => k.name == value,
    orElse: () => ContactKind.owner,
  );
}

class Contact extends Equatable {
  const Contact({
    required this.name,
    required this.kind,
    this.phone = '',
    this.note = '',
  });

  factory Contact.fromMap(JsonMap map) => Contact(
    name: map['name'] as String? ?? '',
    kind: ContactKind.parse(map['kind']),
    phone: map['phone'] as String? ?? '',
    note: map['note'] as String? ?? '',
  );

  final String name;
  final ContactKind kind;
  final String phone;
  final String note;

  JsonMap toMap() => {
    'name': name,
    'kind': kind.name,
    'phone': phone,
    'note': note,
  };

  @override
  List<Object?> get props => [name, kind, phone, note];
}

class Apartment extends Equatable {
  const Apartment({
    required this.id,
    required this.number,
    this.floor,
    this.status = ApartmentStatus.unknown,
    this.feeEligible = true,
    this.notes = '',
    this.contacts = const [],
  });

  factory Apartment.fromMap(String id, JsonMap map) => Apartment(
    id: id,
    number: (map['number'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
    floor: (map['floor'] as num?)?.toInt(),
    status: ApartmentStatus.parse(map['status']),
    feeEligible: map['feeEligible'] as bool? ?? true,
    notes: map['notes'] as String? ?? '',
    contacts: [
      for (final c in (map['contacts'] as List<dynamic>? ?? const []))
        Contact.fromMap(Map<String, dynamic>.from(c as Map)),
    ],
  );

  final String id;
  final int number;
  final int? floor;
  final ApartmentStatus status;

  /// Whether monthly dues are generated for this apartment. Always an
  /// explicit decision; never derived from [status].
  final bool feeEligible;
  final String notes;
  final List<Contact> contacts;

  /// Name shown in lists: first owner, else first contact, else null when
  /// nobody is registered (shown as "غير معروف", never a made-up name).
  String? get displayName {
    if (contacts.isEmpty) return null;
    final owner = contacts.where((c) => c.kind == ContactKind.owner);
    final name = (owner.isEmpty ? contacts.first : owner.first).name.trim();
    return name.isEmpty ? null : name;
  }

  Apartment copyWith({
    int? Function()? floor,
    ApartmentStatus? status,
    bool? feeEligible,
    String? notes,
    List<Contact>? contacts,
  }) => Apartment(
    id: id,
    number: number,
    floor: floor == null ? this.floor : floor(),
    status: status ?? this.status,
    feeEligible: feeEligible ?? this.feeEligible,
    notes: notes ?? this.notes,
    contacts: contacts ?? this.contacts,
  );

  JsonMap toMap() => {
    'number': number,
    'floor': floor,
    'status': status.name,
    'feeEligible': feeEligible,
    'notes': notes,
    'contacts': [for (final c in contacts) c.toMap()],
  };

  @override
  List<Object?> get props => [
    id,
    number,
    floor,
    status,
    feeEligible,
    notes,
    contacts,
  ];
}
