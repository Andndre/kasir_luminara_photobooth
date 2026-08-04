import 'package:intl/intl.dart';

/// Single source of truth for Rupiah formatting.
///
/// The `NumberFormat` is built once — constructing it per call was showing up
/// in list builders, and it also let two screens drift into different formats.
class Currency {
  const Currency._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// e.g. `Rp 50.000`
  static String format(num amount) => _rupiah.format(amount);

  /// e.g. `50.000` — for text fields, where the symbol is shown as a prefix.
  static String formatPlain(num amount) =>
      NumberFormat.decimalPattern('id_ID').format(amount);

  /// Reads a user-typed amount, ignoring thousands separators, currency symbol
  /// and stray spaces. Returns null when there is no digit at all.
  static int? parse(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }
}
