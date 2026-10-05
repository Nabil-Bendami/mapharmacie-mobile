import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/uuid.dart';
import '../../inventory/domain/warehouse.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../organizations/domain/organization_access.dart';
import '../domain/sale.dart';
import '../providers/cart_provider.dart';
import '../providers/sale_providers.dart';

/// Checkout stays over the scanner; one RPC commits the entire basket.
class CartCheckoutSheet extends ConsumerStatefulWidget {
  const CartCheckoutSheet({
    super.key,
    required this.access,
    required this.lines,
    required this.warehouses,
  });
  final OrganizationAccess access;
  final List<SaleLine> lines;
  final List<Warehouse> warehouses;
  @override
  ConsumerState<CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends ConsumerState<CartCheckoutSheet> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _key = generateUuidV4();
  late String _warehouse;
  SalePaymentChoice _payment = SalePaymentChoice.cash;
  bool _saving = false;
  // Retain the exact request after an uncertain network outcome.
  bool _submitted = false;
  SaleCustomer? _customer;
  String? _error;
  SaleReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _warehouse = widget.warehouses
        .firstWhere((w) => w.isDefault, orElse: () => widget.warehouses.first)
        .id;
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(saleRepositoryProvider);
      if (!_submitted) {
        _customer = null;
        for (final line in widget.lines) {
          final stock = await ref
              .read(inventoryRepositoryProvider)
              .getAvailableStock(
                organizationId: widget.access.organization.id,
                warehouseId: _warehouse,
                productId: line.productId,
              );
          if (stock < line.quantity) {
            throw AppError(
              '${line.productName}: stock insuffisant ($stock disponible).',
            );
          }
        }
        if (_phone.text.trim().isNotEmpty) {
          _customer = await repository.findOrCreateCustomer(
            organizationId: widget.access.organization.id,
            phone: _phone.text,
            fullName: _name.text,
          );
        }
        _submitted = true;
      }
      final first = widget.lines.first;
      final receipt = await repository.completeSale(
        organizationId: widget.access.organization.id,
        organizationName: widget.access.organization.name,
        currency: widget.access.organization.currency,
        warehouseId: _warehouse,
        idempotencyKey: _key,
        productId: first.productId,
        productName: first.productName,
        quantity: first.quantity,
        unitPrice: first.unitPrice,
        taxRate: first.taxRate,
        lines: widget.lines,
        payment: _payment,
        customer: _customer,
      );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(availableStockProvider);
      if (!mounted) return;
      setState(() => _receipt = receipt);
      if (receipt.customerPhone != null) await _whatsapp(receipt);
    } catch (error) {
      // A server rejection rolls back the transaction; editing is safe.
      if (error is AppError ||
          (error is PostgrestException &&
              RegExp(r'^(22|23|42)').hasMatch(error.code ?? ''))) {
        _submitted = false;
      }
      if (mounted) setState(() => _error = AppError.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _whatsapp(SaleReceipt receipt) async {
    try {
      final phone = receipt.customerPhone;
      if (phone == null) return;
      final uri = Uri.https('wa.me', '/${whatsappPhoneDigits(phone)}', {
        'text': receipt.toWhatsAppText(),
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const FormatException('WhatsApp indisponible.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Vente enregistrée. Impossible d’ouvrir WhatsApp; réessayez avec le bouton.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    final locked = _saving || (_submitted && receipt == null);
    final currency = widget.access.organization.currency;
    return PopScope(
      canPop: !locked,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                receipt == null ? 'Confirmer le panier' : 'Vente confirmée',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (receipt != null)
                SelectableText(receipt.toWhatsAppText())
              else ...[
                for (final line in widget.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${line.productName} × ${line.quantity}'),
                    trailing: Text(formatMoney(line.total, currency: currency)),
                  ),
                Text(
                  'Total: ${formatMoney(widget.lines.fold<num>(0, (s, l) => s + l.total), currency: currency)}',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _warehouse,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Dépôt'),
                  items: widget.warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _warehouse = value!),
                ),
                const SizedBox(height: 16),
                SegmentedButton<SalePaymentChoice>(
                  segments: const [
                    ButtonSegment(
                      value: SalePaymentChoice.cash,
                      label: Text('Espèces'),
                    ),
                    ButtonSegment(
                      value: SalePaymentChoice.credit,
                      label: Text('Tal9a / Crédit'),
                    ),
                  ],
                  selected: {_payment},
                  onSelectionChanged: locked
                      ? null
                      : (values) => setState(() => _payment = values.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  enabled: !locked,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro client',
                    hintText: '06… / 07… / +212…',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return _payment == SalePaymentChoice.credit
                          ? 'Numéro obligatoire pour Tal9a.'
                          : null;
                    }
                    return normalizeCustomerPhone(value!) == null
                        ? 'Numéro invalide.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  enabled: !locked,
                  decoration: const InputDecoration(
                    labelText: 'Nom client (optionnel)',
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (receipt == null)
                FilledButton(
                  onPressed: _saving ? null : _confirm,
                  child: Text(
                    _saving
                        ? 'Enregistrement…'
                        : _submitted
                        ? 'Réessayer la même vente'
                        : 'Confirmer la vente',
                  ),
                ),
              if (receipt != null && receipt.customerPhone != null) ...[
                FilledButton(
                  onPressed: () => _whatsapp(receipt),
                  child: const Text('Envoyer sur WhatsApp'),
                ),
                const Text(
                  'Appuyez sur Envoyer dans WhatsApp pour transmettre la facture.',
                ),
              ],
              TextButton(
                onPressed: locked ? null : () => Navigator.pop(context),
                child: Text(
                  receipt == null ? 'Continuer le scan' : 'Nouvelle vente',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
