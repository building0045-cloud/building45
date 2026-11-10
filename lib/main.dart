import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/apartments/data/apartment_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/settings/data/members_repository.dart';
import 'features/sheet_import/data/import_item.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;

  runApp(
    HomeSystemApp(
      authRepository: FirebaseAuthRepository(FirebaseAuth.instance, db),
      apartmentRepository: FirestoreApartmentRepository(db),
      membersRepository: MembersRepository(db),
      importRepository: ImportRepository(db),
    ),
  );
}
