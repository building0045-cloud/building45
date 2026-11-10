import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Public landing page. It will show only the sections the admin chooses to
/// publish; until publishing exists it shows nothing about the building.
class PublicPage extends StatelessWidget {
  const PublicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('مصروفات العمارة'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.lock_outline),
            label: const Text('دخول الإدارة'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apartment, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('لم تُنشر بيانات بعد', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'تظهر هنا البيانات التي تختار إدارة العمارة مشاركتها.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
