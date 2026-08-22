import 'package:flutter_test/flutter_test.dart';
import 'package:ma_pharmacie_mobile/core/utils/barcode.dart';

void main() {
  group('barcode utilities', () {
    test('normalizes whitespace and casing without dropping leading zeros', () {
      expect(normalizeBarcode('  00ab-12  '), '00AB-12');
    });

    test('accepts common retail and QR values', () {
      expect(validateBarcode('6111000001234'), isNull);
      expect(validateBarcode('SKU-100_A'), isNull);
    });

    test('rejects empty and too-short values', () {
      expect(validateBarcode('  '), isNotNull);
      expect(validateBarcode('123'), isNotNull);
    });
  });
}
