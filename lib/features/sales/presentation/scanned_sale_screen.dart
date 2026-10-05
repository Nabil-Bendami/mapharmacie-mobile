import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/uuid.dart';
import '../../inventory/domain/warehouse.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../organizations/domain/organization_access.dart';
import '../../organizations/providers/organization_providers.dart';
import '../../products/domain/product.dart';
import '../../products/providers/product_providers.dart';
import '../domain/sale.dart';
import '../providers/sale_providers.dart';

class ScannedSaleScreen extends ConsumerStatefulWidget {
  const ScannedSaleScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ScannedSaleScreen> createState() => _ScannedSaleScreenState();
}

class _ScannedSaleScreenState extends ConsumerState<ScannedSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _customerName = TextEditingController();
  late final String _idempotencyKey;
  String? _warehouseId;
  String? _error;
  int _quantity = 1;
  bool _saving = false;
  SalePaymentChoice _payment = SalePaymentChoice.cash;
  SaleReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = generateUuidV4();
  }

  @override
  void dispose() {
    _phone.dispose();
    _customerName.dispose();
    super.dispose();
  }

  Future<void> _confirm({
    required OrganizationAccess access,
    required Product product,
    required Warehouse warehouse,
    required num stock,
  }) async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (stock < _quantity) {
      setState(() => _error = 'Stock insuffisant. Disponible: $stock.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      SaleCustomer? customer;
      if (_phone.text.trim().isNotEmpty) {
        customer = await ref
            .read(saleRepositoryProvider)
            .findOrCreateCustomer(
              organizationId: access.organization.id,
              phone: _phone.text,
              fullName: _customerName.text,
            );
      }
      if (_payment == SalePaymentChoice.credit && customer == null) {
        throw const AppError('Le numéro du client est obligatoire pour Tal9a.');
      }
      final receipt = await ref
          .read(saleRepositoryProvider)
          .completeSale(
            organizationId: access.organization.id,
            organizationName: access.organization.name,
            currency: access.organization.currency,
            warehouseId: warehouse.id,
            idempotencyKey: _idempotencyKey,
            productId: product.id,
            productName: product.name,
            quantity: _quantity,
            unitPrice: product.sellingPrice,
            taxRate: product.taxRate,
            payment: _payment,
            customer: customer,
          );
      ref.invalidate(productDetailProvider(product.id));
      ref.invalidate(availableStockProvider);
      if (!mounted) return;
      setState(() => _receipt = receipt);
      if (receipt.customerPhone != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_sendWhatsApp(receipt, automatic: true)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendWhatsApp(
    SaleReceipt receipt, {
    bool automatic = false,
  }) async {
    final phone = receipt.customerPhone;
    if (phone == null) return;
    var opened = false;
    try {
      final uri = Uri.https('wa.me', '/${whatsappPhoneDigits(phone)}', {
        'text': receipt.toWhatsAppText(),
      });
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            automatic
                ? 'Vente enregistrée. Ouvrez WhatsApp avec le bouton ci-dessous.'
                : 'Impossible d’ouvrir WhatsApp sur ce téléphone.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    if (receipt != null) {
      return _ReceiptView(
        receipt: receipt,
        onWhatsApp: () => _sendWhatsApp(receipt),
      );
    }
    final access = ref.watch(currentOrganizationProvider);
    final product = ref.watch(productDetailProvider(widget.productId));
    final warehouses = ref.watch(activeWarehousesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vente par scan')),
      body: access.when(
        loading: _loading,
        error: _errorView,
        data: (current) {
          if (current == null) {
            return const Center(child: Text('Choisissez une pharmacie.'));
          }
          return product.when(
            loading: _loading,
            error: _errorView,
            data: (item) {
              if (item == null) {
                return const Center(child: Text('Produit introuvable.'));
              }
              return warehouses.when(
                loading: _loading,
                error: _errorView,
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun dépôt actif. Ajoutez une réserve d’officine ou un dépôt avant de vendre.',
                        ),
                      ),
                    );
                  }
                  final warehouse = _selectedWarehouse(items);
                  final stock = ref.watch(
                    availableStockProvider((
                      organizationId: current.organization.id,
                      warehouseId: warehouse.id,
                      productId: item.id,
                    )),
                  );
                  return stock.when(
                    loading: _loading,
                    error: _errorView,
                    data: (available) => _buildForm(
                      access: current,
                      product: item,
                      warehouses: items,
                      warehouse: warehouse,
                      stock: available,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Warehouse _selectedWarehouse(List<Warehouse> items) {
    for (final item in items) {
      if (item.id == _warehouseId) return item;
    }
    return items.firstWhere(
      (item) => item.isDefault,
      orElse: () => items.first,
    );
  }

  Widget _buildForm({
    required OrganizationAccess access,
    required Product product,
    required List<Warehouse> warehouses,
    required Warehouse warehouse,
    required num stock,
  }) {
    final subtotal = product.sellingPrice * _quantity;
    final total = subtotal + (subtotal * product.taxRate / 100);
    final canSell = stock >= _quantity && stock > 0;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDDF4EF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stock > 0
                        ? 'Ce produit est déjà en stock · Disponible: $stock'
                        : 'Ce produit existe, mais son stock est à zéro.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(product.barcode ?? 'Sans code-barres'),
                  const SizedBox(height: 12),
                  Text(
                    formatMoney(
                      product.sellingPrice,
                      currency: access.organization.currency,
                    ),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: warehouse.id,
            decoration: const InputDecoration(
              labelText: 'Dépôt',
              prefixIcon: Icon(Icons.warehouse_rounded),
            ),
            items: warehouses
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _warehouseId = value;
                    _quantity = 1;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quantité',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Diminuer la quantité',
                    onPressed: _quantity > 1 && !_saving
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Augmenter la quantité',
                    onPressed: _quantity < stock.floor() && !_saving
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Paiement',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SegmentedButton<SalePaymentChoice>(
            segments: const [
              ButtonSegment(
                value: SalePaymentChoice.cash,
                icon: Icon(Icons.payments_rounded),
                label: Text('Espèces'),
              ),
              ButtonSegment(
                value: SalePaymentChoice.credit,
                icon: Icon(Icons.credit_score_rounded),
                label: Text('Tal9a'),
              ),
            ],
            selected: {_payment},
            onSelectionChanged: _saving
                ? null
                : (selection) => setState(() {
                    _payment = selection.first;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _payment == SalePaymentChoice.credit
                  ? 'Numéro du client *'
                  : 'Numéro du client (optionnel)',
              hintText: '06XXXXXXXX',
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (_payment == SalePaymentChoice.credit && text.isEmpty) {
                return 'Le numéro est obligatoire pour Tal9a.';
              }
              if (text.isNotEmpty && normalizeCustomerPhone(text) == null) {
                return 'Entrez un numéro valide.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom du client (optionnel)',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          if (_payment == SalePaymentChoice.credit)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Le montant complet sera ajouté à la Tal9a du client.',
                style: TextStyle(color: AppColors.muted),
              ),
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
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                formatMoney(total, currency: access.organization.currency),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: !canSell || _saving
                ? null
                : () => _confirm(
                    access: access,
                    product: product,
                    warehouse: warehouse,
                    stock: stock,
                  ),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Enregistrement…' : 'Confirmer la vente'),
          ),
        ],
      ),
    );
  }
}

Widget _loading() => const Center(child: CircularProgressIndicator());

Widget _errorView(Object error, StackTrace _) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(AppError.from(error).message, textAlign: TextAlign.center),
  ),
);

class _ReceiptView extends StatelessWidget {
  const _ReceiptView({required this.receipt, required this.onWhatsApp});

  final SaleReceipt receipt;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vente confirmée')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(
          radius: 38,
          backgroundColor: Color(0xFFDDF4EF),
          child: Icon(Icons.check_rounded, color: AppColors.primary, size: 42),
        ),
        const SizedBox(height: 14),
        Text(
          'Vente enregistrée',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        SelectableText(
          receipt.reference,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _ReceiptLine(
                  label: receipt.productName,
                  value: '× ${receipt.quantity}',
                ),
                _ReceiptLine(
                  label: 'Prix unitaire',
                  value: formatMoney(
                    receipt.unitPrice,
                    currency: receipt.currency,
                  ),
                ),
                _ReceiptLine(
                  label: 'Paiement',
                  value: receipt.amountDue > 0 ? 'Tal9a' : 'Espèces',
                ),
                if (receipt.customerName != null)
                  _ReceiptLine(label: 'Client', value: receipt.customerName!),
                const Divider(height: 28),
                _ReceiptLine(
                  label: 'Total',
                  value: formatMoney(receipt.total, currency: receipt.currency),
                  strong: true,
                ),
                if (receipt.amountDue > 0)
                  _ReceiptLine(
                    label: 'Reste Tal9a',
                    value: formatMoney(
                      receipt.amountDue,
                      currency: receipt.currency,
                    ),
                    strong: true,
                  ),
              ],
            ),
          ),
        ),
        if (receipt.customerPhone != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onWhatsApp,
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Envoyer la facture sur WhatsApp'),
          ),
          const SizedBox(height: 8),
          const Text(
            'WhatsApp ouvre la facture prête à envoyer; appuyez sur Envoyer dans WhatsApp.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/scanner'),
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scanner un autre produit'),
        ),
      ],
    ),
  );
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
