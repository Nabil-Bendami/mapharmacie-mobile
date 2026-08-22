import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/account_repository.dart';
import '../domain/user_profile.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(supabaseProvider)),
);
final userProfileProvider = FutureProvider<UserProfile>(
  (ref) => ref.watch(accountRepositoryProvider).getProfile(),
);
