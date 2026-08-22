import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/barcode.dart';
import '../domain/product.dart';

const _productSelect =
    'id,organization_id,category_id,name,sku,barcode,brand,dosage,form,purchase_price,selling_price,image_url,is_active,category:categories!products_category_same_organization_fk(id,name)';

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
    final data = await _client
        .from('products')
        .insert({
          'organization_id': organizationId,
          'barcode': normalizeBarcode(barcode),
          'name': name.trim(),
          'category_id': categoryId,
          'brand': brand?.trim().isEmpty == true ? null : brand?.trim(),
          'dosage': dosage?.trim().isEmpty == true ? null : dosage?.trim(),
          'form': form?.trim().isEmpty == true ? null : form?.trim(),
          'unit': 'unit',
          'purchase_price': purchasePrice,
          'selling_price': sellingPrice,
          'tax_rate': 0,
          'min_stock': 0,
          'is_active': true,
        })
        .select(_productSelect)
        .single();
    return Product.fromJson(data);
  }
}
