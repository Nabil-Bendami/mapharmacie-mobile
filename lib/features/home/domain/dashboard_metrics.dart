class DashboardMetrics {
  const DashboardMetrics({
    required this.products,
    required this.lowStock,
    required this.outOfStock,
    required this.expiringSoon,
  });
  final int products;
  final int lowStock;
  final int outOfStock;
  final int expiringSoon;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) =>
      DashboardMetrics(
        products: (json['product_count'] as num?)?.toInt() ?? 0,
        lowStock: (json['low_stock_count'] as num?)?.toInt() ?? 0,
        outOfStock: (json['out_of_stock_count'] as num?)?.toInt() ?? 0,
        expiringSoon: (json['expiring_30_days'] as num?)?.toInt() ?? 0,
      );
}
