/// Suggests the notes a customer is likely to hand over for a given total.
///
/// Pulled out of the cash dialog's builder closure so it can be tested without
/// pumping a widget. Pure function: same total in, same list out.
class CashDenominations {
  const CashDenominations._();

  /// Common Indonesian banknotes, ascending.
  static const notes = [5000, 10000, 20000, 50000, 100000];

  static const maxSuggestions = 6;

  /// Always includes [total] itself (exact change) first, then, for each note,
  /// the smallest multiple of it that covers the total.
  ///
  /// e.g. total 12000 -> [12000, 15000, 20000, 50000, 100000]
  static List<int> suggest(int total) {
    if (total <= 0) return const [];

    final suggestions = <int>{total};

    for (final note in notes) {
      if (total < note) {
        suggestions.add(note);
        continue;
      }
      // Round up to the next whole number of this note.
      final rounded = (total / note).ceil() * note;
      if (rounded > total) suggestions.add(rounded);
    }

    final sorted = suggestions.toList()..sort();
    return sorted.take(maxSuggestions).toList();
  }
}
