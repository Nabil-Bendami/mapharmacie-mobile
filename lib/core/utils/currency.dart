String formatMoney(num value, {String currency = 'MAD'}) {
  final fixed = value.toStringAsFixed(2);
  return '$fixed $currency';
}
