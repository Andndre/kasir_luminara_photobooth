/// Lifecycle of a ticket: paid at the till, then redeemed at the booth.
///
/// [dbValue] is persisted in `transactions.status` and must never change.
enum TransactionStatus {
  /// Paid but not yet redeemed — this is what the verifier queue shows.
  paid('PAID', 'Belum Diambil'),

  /// Ticket has been scanned and redeemed.
  completed('COMPLETED', 'Selesai'),

  cancelled('CANCELLED', 'Dibatalkan');

  const TransactionStatus(this.dbValue, this.label);

  /// Persisted string. Frozen — see `transactions.status`.
  final String dbValue;

  /// Indonesian display label for the UI.
  final String label;

  /// Parses a persisted value. Unknown values fall back to [paid], the schema
  /// default, so a bad row degrades to "still in the queue" rather than
  /// disappearing silently.
  static TransactionStatus fromDb(String? value) {
    final normalized = value?.toUpperCase();
    for (final status in values) {
      if (status.dbValue == normalized) return status;
    }
    return paid;
  }

  bool get isRedeemable => this == paid;
}
