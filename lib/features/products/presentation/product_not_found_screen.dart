import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductNotFoundScreen extends StatelessWidget {
  const ProductNotFoundScreen({super.key, required this.barcode});
  final String barcode;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan result')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 38,
              child: Icon(Icons.search_off_rounded, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              'Product not found',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SelectableText(
              barcode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(
                '/products/new?barcode=${Uri.encodeQueryComponent(barcode)}',
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.go('/scanner'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    ),
  );
}
