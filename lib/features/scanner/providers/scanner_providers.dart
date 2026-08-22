import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/barcode_repository.dart';

final barcodeRepositoryProvider = Provider<BarcodeRepository>(
  (ref) => BarcodeRepository(ref.watch(supabaseProvider)),
);
