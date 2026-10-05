import '../../../core/utils/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/barcode.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../organizations/providers/organization_providers.dart';
import '../providers/product_providers.dart';
import '../domain/product.dart';
import 'create_category_dialog.dart';

class QuickAddProductScreen extends ConsumerStatefulWidget {
  const QuickAddProductScreen({super.key, required this.barcode});
  final String barcode;
  @override
  ConsumerState<QuickAddProductScreen> createState() =>
      _QuickAddProductScreenState();
}

class _QuickAddProductScreenState extends ConsumerState<QuickAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestId = generateUuidV4();
  final _name = TextEditingController(),
      _brand = TextEditingController(),
      _dosage = TextEditingController(),
      _form = TextEditingController(),
      _selling = TextEditingController(),
      _purchase = TextEditingController(),
      _stock = TextEditingController();
  final List<Category> _createdCategories = [];
  String? _categoryId, _warehouseId, _error;
  bool _saving = false;

  Future<void> _createCategory() async {
    final access = ref.read(currentOrganizationProvider).asData?.value;
    if (access == null || _saving) return;
    final created = await showDialog<Category>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CreateCategoryDialog(organizationId: access.organization.id),
    );
    if (!mounted || created == null) return;
    setState(() {
      _createdCategories.add(created);
      _categoryId = created.id;
    });
    ref.invalidate(categoriesProvider);
  }

  Widget _categoryPicker(List<Category> items) {
    final choices = {
      for (final item in [...items, ..._createdCategories]) item.id: item,
    };
    return DropdownButtonFormField<String>(
      key: ValueKey(_categoryId),
      initialValue: choices.containsKey(_categoryId) || _categoryId == ''
          ? _categoryId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Catégorie (optionnelle)'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Sans catégorie')),
        for (final item in choices.values)
          DropdownMenuItem(
            value: item.id,
            child: Text(item.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _saving
          ? null
          : (value) => setState(() => _categoryId = value),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _dosage.dispose();
    _form.dispose();
    _selling.dispose();
    _purchase.dispose();
    _stock.dispose();
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
      final warehouses = await ref.read(activeWarehousesProvider.future);
      final quantity = _parseNumber(_stock.text)!;
      if (warehouses.isEmpty && quantity > 0) {
        throw const AppError(
          'Ajoutez une réserve d’officine ou un dépôt dans les paramètres pour enregistrer cette quantité.',
        );
      }
      final warehouse = warehouses.isEmpty
          ? null
          : warehouses.firstWhere(
              (item) => item.id == _warehouseId,
              orElse: () => warehouses.firstWhere(
                (item) => item.isDefault,
                orElse: () => warehouses.first,
              ),
            );
      await ref
          .read(productRepositoryProvider)
          .quickCreate(
            requestId: _requestId,
            initialQuantity: quantity,
            warehouseId: warehouse?.id,
            organizationId: access.organization.id,
            barcode: widget.barcode,
            name: _name.text,
            sellingPrice: _parseNumber(_selling.text)!,
            purchasePrice: _purchase.text.trim().isEmpty
                ? null
                : _parseNumber(_purchase.text),
            categoryId: _categoryId == '' ? null : _categoryId,
            brand: _brand.text,
            dosage: _dosage.text,
            form: _form.text,
          );
      ref.invalidate(productSearchProvider);
      ref.invalidate(activeWarehousesProvider);
      if (mounted) context.go('/scanner');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final warehouses = ref.watch(activeWarehousesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un produit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              initialValue: normalizeBarcode(widget.barcode),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Code-barres',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom du produit *'),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter the product name.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('initial-stock'),
              controller: _stock,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantité disponible *',
                hintText: 'Ex. 24',
                helperText:
                    'Votre stock réel actuel, pas la quantité à vendre.\nSaisissez 0 si le produit est en rupture.',
                helperMaxLines: 3,
                prefixIcon: Icon(Icons.inventory_2_rounded),
              ),
              validator: (value) {
                final number = _parseNumber(value);
                return number == null || number < 0
                    ? 'Saisissez une quantité valide (0 ou plus).'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text(
                  'Catégorie',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _createCategory,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Créer une catégorie'),
                ),
              ],
            ),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Column(
                children: [
                  const Text(
                    'Liste indisponible. Vous pouvez créer une catégorie ou continuer sans catégorie.',
                  ),
                  _categoryPicker(const []),
                  TextButton(
                    onPressed: () => ref.invalidate(categoriesProvider),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
              data: _categoryPicker,
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
                      labelText: 'Prix de vente *',
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
                      labelText: 'Prix d’achat',
                    ),
                    validator: _optionalNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            warehouses.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(AppError.from(error).message),
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                    'Aucun lieu de stock actif. Ajoutez une réserve d’officine ou un dépôt, ou indiquez 0 pour créer uniquement le produit.',
                  );
                }
                final initial =
                    _warehouseId ??
                    items
                        .firstWhere(
                          (item) => item.isDefault,
                          orElse: () => items.first,
                        )
                        .id;
                return DropdownButtonFormField<String>(
                  initialValue: initial,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lieu de stock',
                    prefixIcon: Icon(Icons.warehouse_rounded),
                  ),
                  items: items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _warehouseId = value),
                );
              },
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
                  : const Text('Enregistrer le produit et le stock'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _positiveNumber(String? value) {
  final number = _parseNumber(value);
  return number == null || number < 0 ? 'Enter a valid price.' : null;
}

String? _optionalNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final number = _parseNumber(value);
  return number == null || number < 0 ? 'Enter a valid price.' : null;
}

num? _parseNumber(String? value) {
  final number = num.tryParse((value ?? '').trim().replaceAll(',', '.'));
  return number != null && number.isFinite ? number : null;
}
