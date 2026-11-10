import 'package:flutter_test/flutter_test.dart';
import 'package:home_system/core/phone.dart';
import 'package:home_system/features/apartments/data/apartment.dart';

void main() {
  test('dialableNumber keeps digits and a leading plus', () {
    expect(dialableNumber('010 1234-5678'), '01012345678');
    expect(dialableNumber('+20 (10) 1234 5678'), '+201012345678');
    expect(dialableNumber('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
  });

  test('callable contacts list owners first and skip empty phones', () {
    const apartment = Apartment(
      id: '5',
      number: 5,
      contacts: [
        Contact(name: 'مستأجر', kind: ContactKind.tenant, phone: '011'),
        Contact(name: 'مالك بلا رقم', kind: ContactKind.owner),
        Contact(name: 'مالك', kind: ContactKind.owner, phone: '010'),
      ],
    );

    expect(apartment.callableContacts.map((c) => c.name), ['مالك', 'مستأجر']);
  });

  test('floor 0 is the ground floor', () {
    expect(Apartment.floorName(0), 'الدور الأرضي');
    expect(Apartment.floorName(5), 'الدور الخامس');
  });
}
