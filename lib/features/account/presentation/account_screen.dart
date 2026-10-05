import '../../subscription/subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../organizations/providers/organization_providers.dart';
import '../providers/account_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final access = ref.watch(currentOrganizationProvider).value;
    final user = ref.watch(supabaseProvider).auth.currentUser;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SubscriptionCard(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: profile.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(AppError.from(error).message),
              data: (value) => Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    child: Icon(Icons.person_rounded, size: 34),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value.fullName?.isNotEmpty == true
                        ? value.fullName!
                        : 'Pharmacy user',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '—'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.local_pharmacy_outlined),
                title: const Text('Current organization'),
                subtitle: Text(access?.organization.name ?? '—'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Role'),
                subtitle: Text(access?.role.replaceAll('_', ' ') ?? '—'),
              ),
            ],
          ),
        ),
        if ((ref.watch(organizationAccessProvider).value?.length ?? 0) > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(selectedOrganizationIdProvider.notifier).clear(),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Switch organization'),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
