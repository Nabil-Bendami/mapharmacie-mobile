import 'package:flutter_test/flutter_test.dart';
import 'package:ma_pharmacie_mobile/features/sales/domain/sale.dart';

void main() {
  group('customer phone normalization', () {
    test('normalizes a Moroccan local mobile number', () {
      expect(normalizeCustomerPhone('06 12 34 56 78'), '+212612345678');
      expect(whatsappPhoneDigits('+212612345678'), '212612345678');
    });

    test('rejects incomplete phone numbers', () {
      expect(normalizeCustomerPhone('0612'), isNull);
      expect(normalizeCustomerPhone('012345678'), isNull);
      expect(normalizeCustomerPhone('+2120782967080'), isNull);
      expect(normalizeCustomerPhone('abc0782967080'), isNull);
    });

    test('normalizes legacy customer numbers at the WhatsApp boundary', () {
      for (final input in [
        '0782967080',
        '07 82 96 70 80',
        '782967080',
        '+212782967080',
        '00212782967080',
      ]) {
        expect(whatsappPhoneDigits(input), '212782967080');
      }
      expect(whatsappPhoneDigits('+33612345678'), '33612345678');
      expect(() => whatsappPhoneDigits('123'), throwsFormatException);
    });
  });

  test('credit receipt contains invoice and Tal9a amounts', () {
    final receipt = SaleReceipt(
      saleId: 'sale-id',
      reference: 'SALE-2026-000001',
      organizationName: 'Ma Pharmacie',
      productName: 'Produit test',
      quantity: 2,
      unitPrice: 25,
      total: 50,
      amountPaid: 0,
      amountDue: 50,
      paymentMethod: 'credit',
      currency: 'MAD',
      customerName: 'Client test',
      customerPhone: '+212612345678',
      soldAt: DateTime(2026, 9, 6, 12, 30),
    );

    final message = receipt.toWhatsAppText();
    expect(message, contains('SALE-2026-000001'));
    expect(message, contains('Produit test × 2'));
    expect(message, contains('Tal9a / Crédit'));
    expect(message, contains('Reste (Tal9a): 50.00 MAD'));
  });
}
