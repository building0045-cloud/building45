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
    this.monthlyFee,
    this.notes = '',
    this.contacts = const [],
  });

  factory Apartment.fromMap(String id, JsonMap map) => Apartment(
    id: id,
    number: (map['number'] as num?)?.toInt() ?? int.tryParse(id) ?? 0,
    floor: (map['floor'] as num?)?.toInt(),
    status: ApartmentStatus.parse(map['status']),
    feeEligible: map['feeEligible'] as bool? ?? true,
    monthlyFee: (map['monthlyFee'] as num?)?.toInt(),
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

  /// Monthly subscription in piastres, or null for the building default.
  final int? monthlyFee;
  final String notes;
  final List<Contact> contacts;

  /// Arabic floor name; floor 0 is the ground floor.
  static String floorName(int floor) => switch (floor) {
    0 => 'الدور الأرضي',
    1 => 'الدور الأول',
    2 => 'الدور الثاني',
    3 => 'الدور الثالث',
    4 => 'الدور الرابع',
    5 => 'الدور الخامس',
    _ => 'الدور $floor',
  };

  /// What this apartment owes each month.
  int feeOr(int buildingFee) => monthlyFee ?? buildingFee;

  bool get hasOwner => contacts.any(
    (c) => c.kind == ContactKind.owner && c.name.trim().isNotEmpty,
  );

  /// Has a renter registered beside the owner.
  bool get isRented => contacts.any(
    (c) => c.kind == ContactKind.tenant && c.name.trim().isNotEmpty,
  );

  /// In use: someone is registered and the unit is neither vacant nor
  /// still undelivered.
  bool get inService =>
      contacts.any((c) => c.name.trim().isNotEmpty) &&
      status != ApartmentStatus.notHandedOver &&
      status != ApartmentStatus.vacant;

  /// Contacts that have a phone number, owners first.
  List<Contact> get callableContacts => [
    ...contacts.where(
      (c) => c.kind == ContactKind.owner && c.phone.trim().isNotEmpty,
    ),
    ...contacts.where(
      (c) => c.kind != ContactKind.owner && c.phone.trim().isNotEmpty,
    ),
  ];

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
    int? Function()? monthlyFee,
    String? notes,
    List<Contact>? contacts,
  }) => Apartment(
    id: id,
    number: number,
    floor: floor == null ? this.floor : floor(),
    status: status ?? this.status,
    feeEligible: feeEligible ?? this.feeEligible,
    monthlyFee: monthlyFee == null ? this.monthlyFee : monthlyFee(),
    notes: notes ?? this.notes,
    contacts: contacts ?? this.contacts,
  );

  JsonMap toMap() => {
    'number': number,
    'floor': floor,
    'status': status.name,
    'feeEligible': feeEligible,
    'monthlyFee': monthlyFee,
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
    monthlyFee,
    notes,
    contacts,
  ];
}
