class Product {
  const Product({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.barcode,
    required this.sku,
    required this.brand,
    required this.dosage,
    required this.form,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.taxRate,
    required this.categoryId,
    required this.categoryName,
    required this.imageUrl,
    required this.isActive,
  });
  final String id;
  final String organizationId;
  final String name;
  final String? barcode;
  final String? sku;
  final String? brand;
  final String? dosage;
  final String? form;
  final num? purchasePrice;
  final num sellingPrice;
  final num taxRate;
  final String? categoryId;
  final String? categoryName;
  final String? imageUrl;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] as String,
      organizationId: (json['organization_id'] as String?) ?? '',
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      sku: json['sku'] as String?,
      brand: json['brand'] as String?,
      dosage: json['dosage'] as String?,
      form: json['form'] as String?,
      purchasePrice: json['purchase_price'] as num?,
      sellingPrice: (json['selling_price'] as num?) ?? 0,
      taxRate: (json['tax_rate'] as num?) ?? 0,
      categoryId: json['category_id'] as String?,
      categoryName:
          (json['category_name'] as String?) ?? category?['name'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class ProductPage {
  const ProductPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<Product> items;
  final int total;
  final int page;
  final int pageSize;
}

class Category {
  const Category({required this.id, required this.name});
  final String id;
  final String name;
  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'] as String, name: json['name'] as String);
}
