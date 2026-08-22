import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/organization_repository.dart';
import '../domain/organization_access.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(ref.watch(supabaseProvider)),
);

final organizationAccessProvider = FutureProvider<List<OrganizationAccess>>((
  ref,
) async {
  final auth = await ref.watch(authStateProvider.future);
  if (auth.session == null) return const [];
  return ref.watch(organizationRepositoryProvider).getActiveAccess();
});

class SelectedOrganizationNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String id) => state = id;
  void clear() => state = null;
}

final selectedOrganizationIdProvider =
    NotifierProvider<SelectedOrganizationNotifier, String?>(
      SelectedOrganizationNotifier.new,
    );

final currentOrganizationProvider = FutureProvider<OrganizationAccess?>((
  ref,
) async {
  final selected = ref.watch(selectedOrganizationIdProvider);
  final access = await ref.watch(organizationAccessProvider.future);
  if (access.isEmpty) return null;
  if (access.length == 1) return access.first;
  for (final item in access) {
    if (item.organization.id == selected) return item;
  }
  return null;
});
