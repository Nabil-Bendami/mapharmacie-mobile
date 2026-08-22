import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../organizations/providers/organization_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_metrics.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(supabaseProvider)),
);

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final access = await ref.watch(currentOrganizationProvider.future);
  if (access == null) throw StateError('Select an organization first.');
  return ref
      .watch(dashboardRepositoryProvider)
      .getSummary(access.organization.id);
});
