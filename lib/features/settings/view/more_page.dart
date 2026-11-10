import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/cubit/session_cubit.dart';
import '../../auth/data/member.dart';
import '../data/members_repository.dart';

/// "المزيد": account, staff management (admin only) and sign-out.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    if (session is! SessionActive) return const SizedBox.shrink();
    final me = session.member;
    final repo = context.read<MembersRepository>();
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(me.name),
              subtitle: Text('${me.role.label} · ${me.email}'),
            ),
            if (me.isAdmin) ...[
              const Divider(height: 32),
              Text('طلبات الصلاحية', style: theme.textTheme.titleMedium),
              StreamBuilder<List<AccessRequest>>(
                stream: repo.watchRequests(),
                builder: (context, snap) {
                  final requests = snap.data ?? const <AccessRequest>[];
                  if (snap.hasError) return const _Line('تعذر تحميل الطلبات');
                  if (!snap.hasData) return const LinearProgressIndicator();
                  if (requests.isEmpty) return const _Line('لا توجد طلبات');
                  return Column(
                    children: [
                      for (final r in requests)
                        _RequestTile(request: r, byUid: me.uid),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              Text('المسؤولون', style: theme.textTheme.titleMedium),
              StreamBuilder<List<Member>>(
                stream: repo.watchMembers(),
                builder: (context, snap) {
                  if (snap.hasError) return const _Line('تعذر تحميل القائمة');
                  if (!snap.hasData) return const LinearProgressIndicator();
                  return Column(
                    children: [
                      for (final m in snap.data!)
                        _MemberTile(member: m, me: me),
                    ],
                  );
                },
              ),
            ],
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('بيانات الشيت القديم'),
              subtitle: const Text('نسخة للمراجعة من ملف الإكسل'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.go('/app/sheet'),
            ),
            const Divider(height: 32),
            OutlinedButton.icon(
              onPressed: context.read<SessionCubit>().signOut,
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text),
  );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.byUid});

  final AccessRequest request;
  final String byUid;

  Future<void> _approve(BuildContext context) async {
    final repo = context.read<MembersRepository>();
    final role = await showDialog<MemberRole>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('صلاحية ${request.name}'),
        children: [
          for (final role in [MemberRole.treasurer, MemberRole.admin])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(role),
              child: Text(
                role == MemberRole.admin
                    ? 'مدير: تحكم كامل وإدارة المستخدمين'
                    : 'أمين صندوق: تسجيل وتعديل البيانات',
              ),
            ),
        ],
      ),
    );
    if (role != null) await repo.approve(request, role, byUid: byUid);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(request.name),
      subtitle: Text(request.email, textDirection: TextDirection.ltr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'رفض',
            icon: const Icon(Icons.close),
            onPressed: () =>
                context.read<MembersRepository>().reject(request, byUid: byUid),
          ),
          IconButton(
            tooltip: 'موافقة',
            icon: const Icon(Icons.check),
            onPressed: () => _approve(context),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.me});

  final Member member;
  final Member me;

  @override
  Widget build(BuildContext context) {
    final isMe = member.uid == me.uid;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(isMe ? '${member.name} (أنت)' : member.name),
      subtitle: Text('${member.role.label}${member.active ? '' : ' · موقوف'}'),
    );
  }
}
