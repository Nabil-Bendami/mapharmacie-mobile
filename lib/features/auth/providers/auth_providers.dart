import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield AuthState(AuthChangeEvent.initialSession, repository.currentSession);
  yield* repository.authChanges;
});
