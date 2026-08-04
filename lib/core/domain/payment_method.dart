import 'package:equatable/equatable.dart';

/// How a transaction was paid.
///
/// Deliberately *not* an enum: `transactions.payment_method` already holds
/// free-form Midtrans channel names on shipped installs ("GoPay/GoPay Later",
/// "Bank Transfer (VA)", …). A closed enum would map every one of those to its
/// fallback and silently relabel old rows as cash.
///
/// [dbValue] is persisted and must round-trip unchanged.
class PaymentMethod extends Equatable {
  /// Persisted string. Frozen for the three known values.
  final String dbValue;

  /// Indonesian display label.
  final String label;

  const PaymentMethod._(this.dbValue, this.label);

  static const cash = PaymentMethod._('TUNAI', 'Tunai');
  static const qris = PaymentMethod._('QRIS', 'QRIS');
  static const nonCash = PaymentMethod._('NON-TUNAI', 'Non-Tunai');

  /// The options a cashier can pick at checkout. Anything else only ever
  /// arrives from Midtrans.
  static const selectable = [cash, qris];

  static const _known = [cash, qris, nonCash];

  /// Parses a persisted value, keeping unknown ones verbatim so nothing is
  /// lost. Null/empty falls back to [cash], the schema default.
  factory PaymentMethod.fromDb(String? value) {
    if (value == null || value.isEmpty) return cash;

    final normalized = value.toUpperCase();
    for (final method in _known) {
      if (method.dbValue == normalized) return method;
    }
    // e.g. 'GoPay/GoPay Later' — displayed and stored exactly as received.
    return PaymentMethod._(value, value);
  }

  /// Maps a raw Midtrans channel to what gets stored and shown on the receipt.
  factory PaymentMethod.fromMidtrans(String? rawType) => switch (rawType) {
    null || 'qris' => qris,
    'gopay' => const PaymentMethod._('GoPay/GoPay Later', 'GoPay'),
    'shopeepay' => const PaymentMethod._('ShopeePay/SPayLater', 'ShopeePay'),
    'akulaku' => const PaymentMethod._('Akulaku Paylater', 'Akulaku'),
    'kredivo' => const PaymentMethod._('Kredivo', 'Kredivo'),
    'bank_transfer' ||
    'echannel' ||
    'permata_va' ||
    'bca_va' ||
    'bni_va' ||
    'bri_va' ||
    'cimb_va' ||
    'other_va' => const PaymentMethod._('Bank Transfer (VA)', 'Transfer Bank'),
    _ => PaymentMethod._('QRIS ($rawType)', 'QRIS'),
  };

  /// Only true cash opens the drawer and shows change on the receipt.
  bool get isCash => dbValue.toUpperCase() == cash.dbValue;

  @override
  List<Object?> get props => [dbValue];
}
