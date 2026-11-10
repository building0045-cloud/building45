import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/session_cubit.dart';
import '../data/auth_repository.dart';

/// Shown at `/login`. Picks the right screen for the current session state;
/// an active staff session is redirected to the app by the router.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/building.jpg',
                      height: 260,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.8),
                      semanticLabel: 'مدخل عمارة ٤٥',
                    ),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<SessionCubit, SessionState>(
                    builder: (context, state) => switch (state) {
                      SessionLoading() || SessionActive() => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      SessionSignedOut() => const _LoginForm(),
                      SessionNeedsSetup() => const _SetupForm(),
                      SessionNoAccess() => _NoAccess(state: state),
                      SessionFailure() => const _Failure(),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<AuthRepository>();
    try {
      if (_createAccount) {
        await repo.signUp(_email.text.trim(), _password.text);
      } else {
        await repo.signIn(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _createAccount ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _createAccount
                  ? 'بعد إنشاء الحساب يوافق مدير العمارة على صلاحيتك.'
                  : 'هذه الصفحة لمسؤولي العمارة فقط.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'اكتب بريدًا إلكترونيًا صحيحًا'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              validator: (v) =>
                  (v == null || v.length < 6) ? '٦ أحرف على الأقل' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_createAccount ? 'إنشاء الحساب' : 'دخول'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _createAccount = !_createAccount;
                      _error = null;
                    }),
              child: Text(
                _createAccount
                    ? 'لدي حساب بالفعل'
                    : 'ليس لديك حساب؟ أنشئ حسابًا',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupForm extends StatefulWidget {
  const _SetupForm();

  @override
  State<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<_SetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _building = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _building.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await context.read<SessionCubit>().setupBuilding(
        buildingName: _building.text.trim(),
        adminName: _name.text.trim(),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('تهيئة العمارة لأول مرة', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'لم تُسجَّل عمارة بعد. ستصبح أنت مدير النظام، وتُنشأ ٢٤ شقة '
            'بالأرقام فقط ويمكنك تعديل بياناتها لاحقًا.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _building,
            decoration: const InputDecoration(
              labelText: 'اسم العمارة',
              hintText: 'مثال: عمارة ٤٥ سكن مصر',
            ),
            validator: _required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسمك'),
            validator: _required,
          ),
          if (_failed) ...[
            const SizedBox(height: 16),
            Text(
              'تعذرت التهيئة. تأكد من الاتصال وحاول مرة أخرى.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('إنشاء العمارة'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : context.read<SessionCubit>().signOut,
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class _NoAccess extends StatefulWidget {
  const _NoAccess({required this.state});

  final SessionNoAccess state;

  @override
  State<_NoAccess> createState() => _NoAccessState();
}

class _NoAccessState extends State<_NoAccess> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await context.read<SessionCubit>().requestAccess(_name.text.trim());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final signOut = TextButton(
      onPressed: context.read<SessionCubit>().signOut,
      child: const Text('تسجيل الخروج'),
    );

    if (state.deactivated || state.requested) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.deactivated ? Icons.block : Icons.hourglass_top,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            state.deactivated
                ? 'تم إيقاف صلاحيتك. تواصل مع مدير العمارة.'
                : 'تم إرسال طلبك. ستتمكن من الدخول بعد موافقة مدير العمارة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(state.user.email, textDirection: TextDirection.ltr),
          const SizedBox(height: 16),
          signOut,
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('طلب صلاحية', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('حسابك غير مضاف لإدارة العمارة. أرسل طلبًا للمدير.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسمك'),
            validator: _required,
          ),
          if (_failed) ...[
            const SizedBox(height: 16),
            Text(
              'تعذر إرسال الطلب، حاول مرة أخرى.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('إرسال الطلب'),
          ),
          const SizedBox(height: 8),
          signOut,
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 16),
        const Text('تعذر تحميل بيانات الحساب. تأكد من الاتصال بالإنترنت.'),
        const SizedBox(height: 16),
        TextButton(
          onPressed: context.read<SessionCubit>().signOut,
          child: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }
}

String? _required(String? value) =>
    (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;
