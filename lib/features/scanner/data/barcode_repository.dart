import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/barcode.dart';
import '../domain/barcode_lookup_result.dart';

class BarcodeRepository {
  const BarcodeRepository(this._client);
  final SupabaseClient _client;

  Future<BarcodeLookupResult> lookup(
    String organizationId,
    String rawBarcode,
  ) async {
    final validation = validateBarcode(rawBarcode);
    final barcode = normalizeBarcode(rawBarcode);
    if (validation != null) {
      unawaited(_log(organizationId, barcode, 'invalid', null));
      throw AppError(validation);
    }
    final data = await _client.rpc(
      'lookup_product_by_barcode',
      params: {
        'barcode_input': barcode,
        'organization_id_input': organizationId,
      },
    );
    final rows = List<Map<String, dynamic>>.from(data as List);
    final row = rows.isEmpty ? <String, dynamic>{} : rows.first;
    final found = row['found'] == true && row['id'] != null;
    final result = BarcodeLookupResult(
      found: found,
      barcode: (row['barcode'] as String?) ?? barcode,
      productId: row['id'] as String?,
    );
    unawaited(
      _log(
        organizationId,
        result.barcode,
        found ? 'found' : 'not_found',
        result.productId,
      ),
    );
    return result;
  }

  Future<void> _log(
    String organizationId,
    String barcode,
    String result,
    String? productId,
  ) async {
    if (barcode.isEmpty) return;
    try {
      await _client.from('scan_events').insert({
        'organization_id': organizationId,
        'barcode': barcode.substring(
          0,
          barcode.length > 512 ? 512 : barcode.length,
        ),
        'source': 'mobile',
        'result_type': result,
        'product_id': productId,
      });
    } catch (_) {
      // Scan telemetry must never block product identification.
    }
  }
}
