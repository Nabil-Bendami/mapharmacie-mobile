final _machineCodePattern = RegExp(r'^[A-Za-z0-9._-]+$');

String normalizeBarcode(String value) {
  final compact = value.trim().replaceAll(RegExp(r'\s+'), '');
  return _machineCodePattern.hasMatch(compact)
      ? compact.toUpperCase()
      : compact;
}

String? validateBarcode(String value) {
  final normalized = normalizeBarcode(value);
  if (normalized.isEmpty) {
    return 'Enter or scan a barcode.';
  }
  if (normalized.length < 4) {
    return 'Barcode must contain at least 4 characters.';
  }
  if (normalized.length > 512) {
    return 'Barcode cannot exceed 512 characters.';
  }
  if (normalized.runes.any((code) => code <= 31 || code == 127)) {
    return 'Barcode contains unsupported characters.';
  }
  return null;
}
