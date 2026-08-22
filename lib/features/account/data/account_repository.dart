import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_profile.dart';

class AccountRepository {
  const AccountRepository(this._client);
  final SupabaseClient _client;
  Future<UserProfile> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Authentication required');
    final data = await _client
        .from('profiles')
        .select('full_name,phone')
        .eq('id', user.id)
        .maybeSingle();
    return UserProfile.fromJson(data ?? const {});
  }
}
