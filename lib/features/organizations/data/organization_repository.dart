import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/organization_access.dart';

class OrganizationRepository {
  const OrganizationRepository(this._client);
  final SupabaseClient _client;

  Future<List<OrganizationAccess>> getActiveAccess() async {
    final membershipData = await _client
        .from('organization_members')
        .select('id,organization_id,role')
        .eq('status', 'active');
    final memberships = List<Map<String, dynamic>>.from(membershipData);
    if (memberships.isEmpty) return const [];
    final ids = memberships
        .map((row) => row['organization_id'] as String)
        .toList();
    final organizationData = await _client
        .from('organizations')
        .select('id,name,currency,locale')
        .inFilter('id', ids);
    final organizations = {
      for (final row in List<Map<String, dynamic>>.from(organizationData))
        row['id'] as String: PharmacyOrganization.fromJson(row),
    };
    return memberships
        .where((row) => organizations.containsKey(row['organization_id']))
        .map(
          (row) => OrganizationAccess(
            membershipId: row['id'] as String,
            role: row['role'] as String,
            organization: organizations[row['organization_id']]!,
          ),
        )
        .toList();
  }
}
