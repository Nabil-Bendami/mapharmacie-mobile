import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/warehouse.dart';

class InventoryRepository {
  const InventoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Warehouse>> getActiveWarehouses(String organizationId) async {
    final data = await _client
        .from('warehouses')
        .select('id,name,is_default,location_kind')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('name');
    return List<Map<String, dynamic>>.from(
      data,
    ).map(Warehouse.fromJson).toList();
  }

  Future<num> getAvailableStock({
    required String organizationId,
    required String warehouseId,
    required String productId,
  }) async {
    final data = await _client.rpc(
      'get_pos_stock_availability',
      params: {
        'organization_id_input': organizationId,
        'warehouse_id_input': warehouseId,
        'product_ids_input': [productId],
      },
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    return rows.isEmpty ? 0 : (rows.first['quantity'] as num?) ?? 0;
  }

  Future<num> addOpeningStock({
    required String productId,
    required String warehouseId,
    required num quantity,
  }) async {
    final data = await _client.rpc(
      'create_stock_movement',
      params: {
        'product_id_input': productId,
        'warehouse_id_input': warehouseId,
        'quantity_input': quantity,
        'movement_type_input': 'opening_stock',
        'reference_type_input': 'mobile_quick_add',
        'reason_input': 'Initial stock from mobile product creation',
        'reference_id_input': null,
      },
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    return rows.isEmpty
        ? quantity
        : (rows.first['new_stock'] as num?) ?? quantity;
  }
}
