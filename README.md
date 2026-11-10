# Home System

Arabic web app for managing a residential building's finances (Flutter Web + Firebase).

## Run

```sh
flutter run -d chrome
```

The first account to sign up while no building exists becomes the owner and admin. Later accounts send an access request that an admin approves under المزيد.

## Checks

```sh
flutter analyze
flutter test
```

Security rule tests (need Java 21+ for the Firestore emulator):

```sh
cd test/rules && npm install && npm test
```

## Deploy rules

```sh
firebase deploy --only firestore,auth
```

## Layout

- `lib/core/` shared Firestore references
- `lib/features/<feature>/{data,cubit,view}` feature-first code
- `firestore.rules` server-side access control
- `test/rules/` rule tests
