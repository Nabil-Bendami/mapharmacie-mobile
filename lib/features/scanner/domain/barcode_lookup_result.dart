class BarcodeLookupResult {
  const BarcodeLookupResult({
    required this.found,
    required this.barcode,
    this.productId,
  });
  final bool found;
  final String barcode;
  final String? productId;
}

class ScanLock {
  bool _locked = false;
  bool acquire() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  void release() => _locked = false;
  bool get isLocked => _locked;
}
