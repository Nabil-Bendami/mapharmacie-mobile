import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/barcode.dart';
import '../../organizations/providers/organization_providers.dart';
import '../providers/product_providers.dart';

class QuickAddProductScreen extends ConsumerStatefulWidget {
  const QuickAddProductScreen({super.key, required this.barcode});
  final String barcode;
  @override
  ConsumerState<QuickAddProductScreen> createState() =>
      _QuickAddProductScreenState();
}

class _QuickAddProductScreenState extends ConsumerState<QuickAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _brand = TextEditingController(),
      _dosage = TextEditingController(),
      _form = TextEditingController(),
      _selling = TextEditingController(),
      _purchase = TextEditingController();
  String? _categoryId, _error;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _dosage.dispose();
    _form.dispose();
    _selling.dispose();
    _purchase.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final access = await ref.read(currentOrganizationProvider.future);
      if (access == null) throw StateError('Select an organization.');
      final product = await ref
          .read(productRepositoryProvider)
          .quickCreate(
            organizationId: access.organization.id,
            barcode: widget.barcode,
            name: _name.text,
            sellingPrice: num.parse(_selling.text),
            purchasePrice: _purchase.text.trim().isEmpty
                ? null
                : num.parse(_purchase.text),
            categoryId: _categoryId,
            brand: _brand.text,
            dosage: _dosage.text,
            form: _form.text,
          );
      ref.invalidate(productSearchProvider);
      if (mounted) context.go('/products/${product.id}');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Quick add product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              initialValue: normalizeBarcode(widget.barcode),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Product name *'),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter the product name.'
                  : null,
            ),
            const SizedBox(height: 14),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text(
                'Categories unavailable. Product can be saved uncategorized.',
              ),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _selling,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Selling price *',
                    ),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _purchase,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase price',
                    ),
                    validator: _optionalNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dosage,
                    decoration: const InputDecoration(labelText: 'Dosage'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _form,
                    decoration: const InputDecoration(labelText: 'Form'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save product'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _positiveNumber(String? value) {
  final number = num.tryParse(value ?? '');
  return number == null || number < 0 ? 'Enter a valid price.' : null;
}

String? _optionalNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final number = num.tryParse(value);
  return number == null || number < 0 ? 'Enter a valid price.' : null;
}
