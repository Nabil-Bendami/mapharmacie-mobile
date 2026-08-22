import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/widgets/app_async_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/organization_access.dart';
import '../providers/organization_providers.dart';

class OrganizationGate extends ConsumerWidget {
  const OrganizationGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(organizationAccessProvider);
    return access.when(
      loading: () =>
          const Scaffold(body: AppLoadingView(label: 'Loading your pharmacy…')),
      error: (error, _) => Scaffold(
        body: AppErrorView(
          message: AppError.from(error).message,
          onRetry: () => ref.invalidate(organizationAccessProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const _NoOrganizationScreen();
        final selected = ref.watch(selectedOrganizationIdProvider);
        if (items.length > 1 &&
            !items.any((item) => item.organization.id == selected)) {
          return OrganizationSelectionScreen(access: items);
        }
        return child;
      },
    );
  }
}

class OrganizationSelectionScreen extends ConsumerWidget {
  const OrganizationSelectionScreen({super.key, required this.access});
  final List<OrganizationAccess> access;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Choose a pharmacy')),
    body: ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: access.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = access[index];
        return Card(
          child: ListTile(
            minTileHeight: 72,
            leading: const CircleAvatar(
              child: Icon(Icons.local_pharmacy_rounded),
            ),
            title: Text(
              item.organization.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(item.role.replaceAll('_', ' ')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ref
                .read(selectedOrganizationIdProvider.notifier)
                .select(item.organization.id),
          ),
        );
      },
    ),
  );
}

class _NoOrganizationScreen extends ConsumerWidget {
  const _NoOrganizationScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              'No active organization',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask an administrator to add or reactivate your pharmacy membership.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}
