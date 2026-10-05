import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_pharmacie_mobile/features/organizations/providers/organization_providers.dart';
import 'package:ma_pharmacie_mobile/features/sales/providers/cart_provider.dart';
import 'package:ma_pharmacie_mobile/features/sales/data/sale_repository.dart';
import 'package:ma_pharmacie_mobile/features/sales/domain/sale.dart';

const first = SaleLine(
  productId: 'a',
  productName: 'Produit A',
  quantity: 1,
  unitPrice: 10,
  taxRate: 20,
);
const second = SaleLine(
  productId: 'b',
  productName: 'Produit B',
  quantity: 2,
  unitPrice: 5,
  taxRate: 0,
);

void main() {
  test(
    'cart merges repeated scans, edits quantities, removes and clears',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentOrganizationProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentOrganizationProvider.future);
      final cart = container.read(cartProvider.notifier);
      cart.add(first);
      cart.add(second);
      cart.add(first);
      expect(container.read(cartProvider).length, 2);
      expect(container.read(cartProvider).first.quantity, 2);
      cart.setQuantity('a', 3);
      expect(container.read(cartProvider).first.quantity, 3);
      cart.setQuantity('a', 0);
      expect(container.read(cartProvider).single.productId, 'b');
      cart.clear();
      expect(container.read(cartProvider), isEmpty);
    },
  );

  test('line total rounds subtotal and tax separately like the server', () {
    const line = SaleLine(
      productId: 'a',
      productName: 'A',
      quantity: 3,
      unitPrice: 1.235,
      taxRate: 20,
    );
    expect(line.total, 4.45);
  });

  for (final payment in SalePaymentChoice.values) {
    test(
      'checkout sends one multi-product RPC and creates a $payment receipt',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final requests = <Map<String, dynamic>>[];
        server.listen((request) async {
          expect(request.uri.path, '/rest/v1/rpc/complete_sale');
          requests.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode([
              {
                'sale_id': 'sale',
                'sale_reference': 'SALE-001',
                'sale_total': 22,
                'amount_paid': payment == SalePaymentChoice.cash ? 22 : 0,
                'amount_due': payment == SalePaymentChoice.credit ? 22 : 0,
                'payment_method': 'cash',
              },
            ]),
          );
          await request.response.close();
        });
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'test-key',
        );
        addTearDown(client.dispose);
        final receipt = await SaleRepository(client).completeSale(
          organizationId: 'org',
          organizationName: 'Pharmacie',
          currency: 'MAD',
          warehouseId: 'warehouse',
          idempotencyKey: 'same-key',
          productId: first.productId,
          productName: first.productName,
          quantity: first.quantity,
          unitPrice: first.unitPrice,
          taxRate: first.taxRate,
          lines: [first, second],
          payment: payment,
          customer: const SaleCustomer(
            id: 'customer',
            fullName: 'Client',
            phone: '0782967080',
          ),
        );
        expect(requests.length, 1);
        expect(requests.single['items_input'], [
          first.toJson(),
          second.toJson(),
        ]);
        expect(requests.single['idempotency_key_input'], 'same-key');
        expect(
          requests.single['amount_tendered_input'],
          payment == SalePaymentChoice.cash ? 22 : 0,
        );
        expect(receipt.lines.length, 2);
        expect(receipt.toWhatsAppText(), contains('Produit A × 1'));
        expect(receipt.toWhatsAppText(), contains('Produit B × 2'));
        expect(whatsappPhoneDigits(receipt.customerPhone!), '212782967080');
        if (payment == SalePaymentChoice.credit) {
          expect(receipt.toWhatsAppText(), contains('Tal9a / Crédit'));
        }
      },
    );
  }
}
