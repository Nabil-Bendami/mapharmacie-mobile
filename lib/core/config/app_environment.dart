class AppEnvironment {
  const AppEnvironment._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Start Flutter with '
        '--dart-define-from-file=config/env.json or pass both --dart-define values.',
      );
    }
    if (supabaseAnonKey.toLowerCase().contains('service_role')) {
      throw StateError(
        'Never use a Supabase service-role key in the mobile app.',
      );
    }
  }
}
