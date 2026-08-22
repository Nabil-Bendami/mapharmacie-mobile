import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../domain/product.dart';
import '../providers/product_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(productPageProvider.notifier).set(1);
      ref.read(productSearchQueryProvider.notifier).set(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(productSearchProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Name, barcode, SKU, or brand',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        result.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(AppError.from(error).message),
                  TextButton(
                    onPressed: () => ref.invalidate(productSearchProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (page) => Column(
            children: [
              if (page.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(44),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 42,
                        color: AppColors.muted,
                      ),
                      SizedBox(height: 10),
                      Text('No products found.'),
                    ],
                  ),
                ),
              ...page.items.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProductTile(product: product),
                ),
              ),
              if (page.total > page.pageSize)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: page.page > 1
                            ? () => ref
                                  .read(productPageProvider.notifier)
                                  .set(page.page - 1)
                            : null,
                        child: const Text('Previous'),
                      ),
                      Text(
                        '${page.page} / ${(page.total / page.pageSize).ceil()}',
                      ),
                      OutlinedButton(
                        onPressed: page.page * page.pageSize < page.total
                            ? () => ref
                                  .read(productPageProvider.notifier)
                                  .set(page.page + 1)
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minTileHeight: 82,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFDDF4EF),
        backgroundImage: product.imageUrl == null
            ? null
            : NetworkImage(product.imageUrl!),
        child: product.imageUrl == null
            ? const Icon(Icons.medication_outlined, color: AppColors.primary)
            : null,
      ),
      title: Text(
        product.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          product.brand,
          product.dosage,
          product.barcode,
        ].whereType<String>().join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(product.sellingPrice),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
      onTap: () => context.push('/products/${product.id}'),
    ),
  );
}
