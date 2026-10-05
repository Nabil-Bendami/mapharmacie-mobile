import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/organizations/presentation/organization_gate.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/product_not_found_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/quick_add_product_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/sales/presentation/scanned_sale_screen.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseProvider);
  final refresh = _AuthRefreshNotifier(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authenticated = client.auth.currentSession != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!authenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (_, _, child) =>
            OrganizationGate(child: MainShell(child: child)),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/scanner', builder: (_, _) => const ScannerScreen()),
          GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        ],
      ),
      GoRoute(
        path: '/sales/new/:productId',
        builder: (_, state) => OrganizationGate(
          child: ScannedSaleScreen(
            productId: state.pathParameters['productId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/products/new',
        builder: (_, state) => OrganizationGate(
          child: QuickAddProductScreen(
            barcode: state.uri.queryParameters['barcode'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) => OrganizationGate(
          child: ProductDetailScreen(
            productId: state.pathParameters['id']!,
            showScanActions: state.uri.queryParameters['from'] == 'scan',
          ),
        ),
      ),
      GoRoute(
        path: '/scanner/not-found',
        builder: (_, state) => OrganizationGate(
          child: ProductNotFoundScreen(
            barcode: state.uri.queryParameters['barcode'] ?? '',
          ),
        ),
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> _subscription;
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
