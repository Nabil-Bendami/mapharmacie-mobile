import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../organizations/providers/organization_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/warehouse.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(supabaseProvider)),
);

final activeWarehousesProvider = FutureProvider<List<Warehouse>>((ref) async {
  final access = await ref.watch(currentOrganizationProvider.future);
  if (access == null) return const [];
  return ref
      .watch(inventoryRepositoryProvider)
      .getActiveWarehouses(access.organization.id);
});

typedef StockRequest = ({
  String organizationId,
  String warehouseId,
  String productId,
});

final availableStockProvider = FutureProvider.family<num, StockRequest>((
  ref,
  request,
) {
  return ref
      .watch(inventoryRepositoryProvider)
      .getAvailableStock(
        organizationId: request.organizationId,
        warehouseId: request.warehouseId,
        productId: request.productId,
      );
});
