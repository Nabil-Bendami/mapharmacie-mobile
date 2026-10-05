import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sale.dart';

class SaleRepository {
  const SaleRepository(this._client);

  final SupabaseClient _client;

  Future<SaleCustomer> findOrCreateCustomer({
    required String organizationId,
    required String phone,
    String? fullName,
  }) async {
    final canonical = normalizeCustomerPhone(phone);
    if (canonical == null) throw const FormatException('Invalid phone number.');
    final local = canonical.startsWith('+212')
        ? '0${canonical.substring(4)}'
        : canonical;
    final data = await _client
        .from('customers')
        .select('id,full_name,phone')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .inFilter('phone', {canonical, local, canonical.substring(1)}.toList())
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isNotEmpty) return SaleCustomer.fromJson(rows.first);

    final cleanedName = fullName?.trim();
    final created = await _client
        .from('customers')
        .insert({
          'organization_id': organizationId,
          'full_name': cleanedName == null || cleanedName.length < 2
              ? 'Client $local'
              : cleanedName,
          'phone': canonical,
        })
        .select('id,full_name,phone')
        .single();
    return SaleCustomer.fromJson(created);
  }

  Future<SaleReceipt> completeSale({
    required String organizationId,
    required String organizationName,
    required String currency,
    required String warehouseId,
    required String idempotencyKey,
    required String productId,
    required String productName,
    required int quantity,
    required num unitPrice,
    required num taxRate,
    required SalePaymentChoice payment,
    SaleCustomer? customer,
    List<SaleLine>? lines,
  }) async {
    final credit = payment == SalePaymentChoice.credit;
    final cart =
        lines ??
        [
          SaleLine(
            productId: productId,
            productName: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            taxRate: taxRate,
          ),
        ];
    if (cart.isEmpty ||
        cart.any((line) => line.quantity <= 0) ||
        cart.map((line) => line.productId).toSet().length != cart.length) {
      throw const FormatException('Panier invalide.');
    }
    final estimatedTotal = cart.fold<num>(
      0,
      (total, line) => total + line.total,
    );
    final data = await _client.rpc(
      'complete_sale',
      params: {
        'organization_id_input': organizationId,
        'warehouse_id_input': warehouseId,
        'idempotency_key_input': idempotencyKey,
        'items_input': cart.map((line) => line.toJson()).toList(),
        'payment_method_input': 'cash',
        'amount_tendered_input': credit ? 0 : estimatedTotal,
        'payment_reference_input': null,
        'discount_amount_input': 0,
        'notes_input': 'Mobile barcode checkout',
        'customer_id_input': customer?.id,
        'amount_paid_input': credit ? 0 : null,
      },
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    if (rows.isEmpty) throw StateError('The sale did not return a receipt.');
    final row = rows.first;
    return SaleReceipt(
      saleId: row['sale_id'] as String,
      reference: row['sale_reference'] as String,
      organizationName: organizationName,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      total: (row['sale_total'] as num?) ?? estimatedTotal,
      amountPaid: (row['amount_paid'] as num?) ?? 0,
      amountDue: (row['amount_due'] as num?) ?? 0,
      paymentMethod: (row['payment_method'] as String?) ?? 'cash',
      currency: currency,
      customerName: customer?.fullName,
      customerPhone: customer?.phone,
      soldAt: DateTime.now(),
      lines: List.unmodifiable(cart),
    );
  }
}
