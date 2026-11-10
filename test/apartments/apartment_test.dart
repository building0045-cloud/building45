import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/features/apartments/data/apartment.dart';

void main() {
  group('Apartment', () {
    test('round-trips through its map form', () {
      const apartment = Apartment(
        id: '7',
        number: 7,
        floor: 2,
        status: ApartmentStatus.occupied,
        feeEligible: false,
        notes: 'ملاحظة',
        contacts: [
          Contact(name: 'مستأجر', kind: ContactKind.tenant, phone: '010'),
          Contact(name: 'مالك', kind: ContactKind.owner),
        ],
      );

      expect(Apartment.fromMap('7', apartment.toMap()), apartment);
    });

    test('has no display name when nobody is registered', () {
      final apartment = Apartment.fromMap('3', {'number': 3});

      expect(apartment.displayName, isNull);
      expect(apartment.status, ApartmentStatus.unknown);
    });

    test('stays fee-eligible by default whatever the status', () {
      final apartment = Apartment.fromMap('1', {
        'number': 1,
        'status': 'notHandedOver',
      });

      expect(apartment.status, ApartmentStatus.notHandedOver);
      expect(apartment.feeEligible, isTrue);
    });

    test('prefers the owner as display name', () {
      const apartment = Apartment(
        id: '7',
        number: 7,
        contacts: [
          Contact(name: 'مستأجر', kind: ContactKind.tenant),
          Contact(name: 'مالك', kind: ContactKind.owner),
        ],
      );

      expect(apartment.displayName, 'مالك');
    });

    test('copyWith can clear the floor', () {
      const apartment = Apartment(id: '2', number: 2, floor: 1);

      expect(apartment.copyWith(floor: () => null).floor, isNull);
      expect(apartment.copyWith(notes: 'x').floor, 1);
    });

    test('in service, rented and not in use', () {
      const owner = Contact(name: 'مالك', kind: ContactKind.owner);
      const tenant = Contact(name: 'مستأجر', kind: ContactKind.tenant);

      const rented = Apartment(
        id: '1',
        number: 1,
        status: ApartmentStatus.occupied,
        contacts: [owner, tenant],
      );
      const ownerOnly = Apartment(id: '2', number: 2, contacts: [owner]);
      const nobody = Apartment(id: '3', number: 3);
      const undelivered = Apartment(
        id: '4',
        number: 4,
        status: ApartmentStatus.notHandedOver,
        contacts: [owner],
      );

      expect([rented.inService, rented.isRented], [true, true]);
      expect([ownerOnly.inService, ownerOnly.isRented], [true, false]);
      expect(nobody.inService, isFalse);
      expect(undelivered.inService, isFalse);
    });
  });
}
