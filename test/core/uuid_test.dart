import 'package:flutter_test/flutter_test.dart';
import 'package:ma_pharmacie_mobile/core/utils/uuid.dart';

void main() {
  test('generates distinct RFC 4122 version 4 identifiers', () {
    final first = generateUuidV4();
    final second = generateUuidV4();
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(first, matches(pattern));
    expect(second, matches(pattern));
    expect(first, isNot(second));
  });
}
