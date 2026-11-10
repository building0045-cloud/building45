import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'features/apartments/cubit/apartments_cubit.dart';
import 'features/apartments/data/apartment_repository.dart';
import 'features/apartments/view/apartment_page.dart';
import 'features/auth/cubit/session_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/view/auth_gate.dart';
import 'features/public/view/public_page.dart';
import 'features/settings/data/members_repository.dart';
import 'features/sheet_import/data/import_item.dart';
import 'features/sheet_import/view/sheet_data_page.dart';
import 'features/shell/view/home_shell.dart';

class HomeSystemApp extends StatefulWidget {
  const HomeSystemApp({
    super.key,
    required this.authRepository,
    required this.apartmentRepository,
    required this.membersRepository,
    required this.importRepository,
  });

  final AuthRepository authRepository;
  final ApartmentRepository apartmentRepository;
  final MembersRepository membersRepository;
  final ImportRepository importRepository;

  @override
  State<HomeSystemApp> createState() => _HomeSystemAppState();
}

class _HomeSystemAppState extends State<HomeSystemApp> {
  late final SessionCubit _session = SessionCubit(widget.authRepository);
  late final _StreamListenable _refresh = _StreamListenable(_session.stream);
  late final GoRouter _router = GoRouter(
    refreshListenable: _refresh,
    redirect: (context, state) {
      final active = _session.state is SessionActive;
      final path = state.matchedLocation;
      if (path.startsWith('/app') && !active) return '/login';
      if (path == '/login' && active) return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PublicPage()),
      GoRoute(path: '/login', builder: (_, _) => const AuthGate()),
      // Staff-only data is loaded only once a staff session is active.
      ShellRoute(
        builder: (_, _, child) => BlocProvider(
          create: (_) => ApartmentsCubit(widget.apartmentRepository),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/app',
            builder: (_, _) => const HomeShell(),
            routes: [
              GoRoute(path: 'sheet', builder: (_, _) => const SheetDataPage()),
              GoRoute(
                path: 'apartments/:id',
                builder: (_, state) =>
                    ApartmentPage(apartmentId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.authRepository),
        RepositoryProvider.value(value: widget.membersRepository),
        RepositoryProvider.value(value: widget.importRepository),
      ],
      child: BlocProvider.value(
        value: _session,
        child: MaterialApp.router(
          title: 'مصروفات العمارة',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: _theme(),
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}

ThemeData _theme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  ),
);

/// Notifies the router whenever the session changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
