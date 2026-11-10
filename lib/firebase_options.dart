import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase web configuration. These values identify the project and are
/// safe to publish; access is enforced by `firestore.rules`.
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyB7AXi8Kz3ewiKddqgIa0w5oad0gf-5sq0',
    appId: '1:246563264696:web:2ea4f9e6062d5f59aa3c4d',
    messagingSenderId: '246563264696',
    projectId: 'home-system-b45',
    authDomain: 'home-system-b45.firebaseapp.com',
    storageBucket: 'home-system-b45.firebasestorage.app',
  );
}
