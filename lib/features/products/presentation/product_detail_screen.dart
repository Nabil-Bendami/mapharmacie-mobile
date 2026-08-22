import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../providers/product_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.showScanActions = false,
  });
  final String productId;
  final bool showScanActions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));
    return Scaffold(
      appBar: AppBar(
        title: Text(showScanActions ? 'Scan result' : 'Product details'),
      ),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(AppError.from(error).message)),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Product not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: const Color(0xFFDDF4EF),
                            backgroundImage: item.imageUrl == null
                                ? null
                                : NetworkImage(item.imageUrl!),
                            child: item.imageUrl == null
                                ? const Icon(
                                    Icons.medication_rounded,
                                    color: AppColors.primary,
                                    size: 34,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Chip(
                                  label: Text(
                                    item.isActive ? 'Active' : 'Archived',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _Detail('Barcode', item.barcode),
                      _Detail('Category', item.categoryName),
                      _Detail('Brand', item.brand),
                      _Detail('Dosage', item.dosage),
                      _Detail('Form', item.form),
                      _Detail(
                        'Purchase price',
                        item.purchasePrice == null
                            ? null
                            : formatMoney(item.purchasePrice!),
                      ),
                      _Detail('Selling price', formatMoney(item.sellingPrice)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Stock operations and inventory history will be added in Mobile Phase 2.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
              if (showScanActions) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/scanner'),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan another'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.go('/products/$productId'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('View product'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value?.isNotEmpty == true ? value! : '—',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
