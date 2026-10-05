import '../../../core/utils/currency.dart';

enum SalePaymentChoice { cash, credit }

class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
  });
  final String productId;
  final String productName;
  final int quantity;
  final num unitPrice;
  final num taxRate;
  num get total =>
      ((unitPrice * quantity * 100).round() +
          (unitPrice * quantity * taxRate).round()) /
      100;
  SaleLine withQuantity(int value) => SaleLine(
    productId: productId,
    productName: productName,
    quantity: value,
    unitPrice: unitPrice,
    taxRate: taxRate,
  );
  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
  };
}

class SaleCustomer {
  const SaleCustomer({
    required this.id,
    required this.fullName,
    required this.phone,
  });

  final String id;
  final String fullName;
  final String? phone;

  factory SaleCustomer.fromJson(Map<String, dynamic> json) => SaleCustomer(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    phone: json['phone'] as String?,
  );
}

class SaleReceipt {
  const SaleReceipt({
    required this.saleId,
    required this.reference,
    required this.organizationName,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.amountPaid,
    required this.amountDue,
    required this.paymentMethod,
    required this.currency,
    required this.customerName,
    required this.customerPhone,
    required this.soldAt,
    this.lines = const [],
  });

  final String saleId;
  final String reference;
  final String organizationName;
  final String productName;
  final int quantity;
  final num unitPrice;
  final num total;
  final num amountPaid;
  final num amountDue;
  final String paymentMethod;
  final String currency;
  final String? customerName;
  final String? customerPhone;
  final DateTime soldAt;
  final List<SaleLine> lines;

  String toWhatsAppText() {
    final payment = amountDue > 0 ? 'Tal9a / Crédit' : 'Espèces';
    final buffer = StringBuffer()
      ..writeln('🧾 $organizationName')
      ..writeln('Facture: $reference')
      ..writeln(
        'Date: ${_two(soldAt.day)}/${_two(soldAt.month)}/${soldAt.year} '
        '${_two(soldAt.hour)}:${_two(soldAt.minute)}',
      )
      ..writeln();
    for (final line
        in lines.isEmpty
            ? [
                SaleLine(
                  productId: '',
                  productName: productName,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  taxRate: 0,
                ),
              ]
            : lines) {
      buffer
        ..writeln('${line.productName} × ${line.quantity}')
        ..writeln(
          'Prix unitaire: ${formatMoney(line.unitPrice, currency: currency)}',
        );
    }
    buffer
      ..writeln('Total: ${formatMoney(total, currency: currency)}')
      ..writeln('Paiement: $payment');
    if (amountDue > 0) {
      buffer
        ..writeln('Payé: ${formatMoney(amountPaid, currency: currency)}')
        ..writeln(
          'Reste (Tal9a): ${formatMoney(amountDue, currency: currency)}',
        );
    }
    buffer
      ..writeln()
      ..write('Merci pour votre confiance.');
    return buffer.toString();
  }
}

String? normalizeCustomerPhone(String input) {
  if (RegExp(r'[^\d\s+().-]').hasMatch(input)) return null;
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0') && digits.length == 10) {
    digits = '212${digits.substring(1)}';
  }
  if (digits.length == 9 && RegExp(r'^[567]').hasMatch(digits)) {
    digits = '212$digits';
  }
  if (digits.startsWith('212') &&
      !RegExp(r'^212[567]\d{8}$').hasMatch(digits)) {
    return null;
  }
  if (digits.startsWith('0') || digits.length < 9 || digits.length > 15) {
    return null;
  }
  return '+$digits';
}

String whatsappPhoneDigits(String phone) {
  final normalized = normalizeCustomerPhone(phone);
  if (normalized == null) {
    throw const FormatException('Numéro WhatsApp invalide.');
  }
  return normalized.substring(1);
}

String _two(int value) => value.toString().padLeft(2, '0');
