import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/barcode.dart';
import '../domain/product.dart';

const _productSelect =
    'id,organization_id,category_id,name,sku,barcode,brand,dosage,form,purchase_price,selling_price,tax_rate,image_url,is_active,category:categories!products_category_same_organization_fk(id,name)';

class ProductRepository {
  const ProductRepository(this._client);
  final SupabaseClient _client;

  Future<ProductPage> search({
    required String organizationId,
    required String search,
    required int page,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    var query = _client
        .from('products')
        .select(_productSelect)
        .eq('organization_id', organizationId);
    final cleaned = search
        .trim()
        .replaceAll(RegExp(r'[,()%]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isNotEmpty) {
      query = query.or(
        'name.ilike.%$cleaned%,barcode.ilike.%$cleaned%,sku.ilike.%$cleaned%,brand.ilike.%$cleaned%',
      );
    }
    final response = await query
        .order('created_at', ascending: false)
        .range(from, from + pageSize - 1)
        .count(CountOption.exact);
    return ProductPage(
      items: List<Map<String, dynamic>>.from(
        response.data,
      ).map(Product.fromJson).toList(),
      total: response.count,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Product?> getById(String organizationId, String productId) async {
    final data = await _client
        .from('products')
        .select(_productSelect)
        .eq('organization_id', organizationId)
        .eq('id', productId)
        .maybeSingle();
    return data == null ? null : Product.fromJson(data);
  }

  Future<List<Category>> getCategories(String organizationId) async {
    final data = await _client
        .from('categories')
        .select('id,name')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(
      data,
    ).map(Category.fromJson).toList();
  }

  Future<Product> quickCreate({
    required String requestId,
    num initialQuantity = 0,
    String? warehouseId,
    required String organizationId,
    required String barcode,
    required String name,
    required num sellingPrice,
    String? categoryId,
    String? brand,
    String? dosage,
    String? form,
    num? purchasePrice,
  }) async {
    final data = await _client.rpc(
      'create_product_with_initial_stock',
      params: {
        'organization_id_input': organizationId,
        'product_id_input': requestId,
        'quantity_input': initialQuantity,
        'warehouse_id_input': warehouseId,
        'product_input': {
          'barcode': normalizeBarcode(barcode),
          'name': name.trim(),
          'categoryId': categoryId,
          'brand': brand?.trim(),
          'dosage': dosage?.trim(),
          'form': form?.trim(),
          'unit': 'unit',
          'purchasePrice': purchasePrice,
          'sellingPrice': sellingPrice,
          'taxRate': 0,
          'minStock': 0,
        },
      },
    );
    return Product.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Category> createCategory(String organizationId, String name) async {
    final cleaned = name.trim();
    if (cleaned.length < 2 || cleaned.length > 80) {
      throw const FormatException(
        'Le nom doit contenir entre 2 et 80 caractères.',
      );
    }
    final data = await _client
        .from('categories')
        .insert({
          'organization_id': organizationId,
          'name': cleaned,
          'is_active': true,
        })
        .select('id,name')
        .single();
    return Category.fromJson(data);
  }
}
