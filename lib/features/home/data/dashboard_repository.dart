import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_metrics.dart';

class DashboardRepository {
  const DashboardRepository(this._client);
  final SupabaseClient _client;

  Future<DashboardMetrics> getSummary(String organizationId) async {
    final data = await _client.rpc(
      'get_dashboard_summary',
      params: {'organization_id_input': organizationId},
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    return DashboardMetrics.fromJson(rows.isEmpty ? const {} : rows.first);
  }
}
