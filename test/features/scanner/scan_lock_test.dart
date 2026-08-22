import 'package:flutter_test/flutter_test.dart';
import 'package:ma_pharmacie_mobile/features/scanner/domain/barcode_lookup_result.dart';

void main() {
  test('scan lock prevents duplicate lookups until released', () {
    final lock = ScanLock();
    expect(lock.acquire(), isTrue);
    expect(lock.acquire(), isFalse);
    expect(lock.isLocked, isTrue);
    lock.release();
    expect(lock.acquire(), isTrue);
  });
}
