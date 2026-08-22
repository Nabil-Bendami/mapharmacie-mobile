import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../organizations/providers/organization_providers.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(supabaseProvider)),
);

class ProductSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

class ProductPageNotifier extends Notifier<int> {
  @override
  int build() => 1;
  void set(int value) => state = value < 1 ? 1 : value;
}

final productSearchQueryProvider =
    NotifierProvider<ProductSearchQueryNotifier, String>(
      ProductSearchQueryNotifier.new,
    );
final productPageProvider = NotifierProvider<ProductPageNotifier, int>(
  ProductPageNotifier.new,
);

final productSearchProvider = FutureProvider<ProductPage>((ref) async {
  final organization = await ref.watch(currentOrganizationProvider.future);
  if (organization == null) throw StateError('Select an organization.');
  return ref
      .watch(productRepositoryProvider)
      .search(
        organizationId: organization.organization.id,
        search: ref.watch(productSearchQueryProvider),
        page: ref.watch(productPageProvider),
      );
});

final productDetailProvider = FutureProvider.family<Product?, String>((
  ref,
  id,
) async {
  final organization = await ref.watch(currentOrganizationProvider.future);
  if (organization == null) return null;
  return ref
      .watch(productRepositoryProvider)
      .getById(organization.organization.id, id);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final organization = await ref.watch(currentOrganizationProvider.future);
  if (organization == null) return const [];
  return ref
      .watch(productRepositoryProvider)
      .getCategories(organization.organization.id);
});
