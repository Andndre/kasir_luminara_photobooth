import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/core.dart';

/// One line in the cart. Holds the [Product] itself rather than an id, so
/// totals never depend on a separate lookup list staying in sync — the old
/// screen kept `Map<int, int>` plus `List<Produk>` and did a
/// `firstWhere((p) => p.id == id)` on every render, which threw if a product
/// was deleted mid-sale.
class CartLine extends Equatable {
  final Product product;
  final int quantity;

  const CartLine({required this.product, required this.quantity});

  int get subtotal => product.price * quantity;

  TransactionItem toTransactionItem() => TransactionItem(
    productName: product.name,
    productPrice: product.price,
    quantity: quantity,
  );

  @override
  List<Object?> get props => [product, quantity];
}

/// Immutable cart. Every mutation returns a new instance.
class Cart extends Equatable {
  final List<CartLine> lines;

  const Cart([this.lines = const []]);

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get totalPrice => lines.fold(0, (sum, l) => sum + l.subtotal);
  int get totalItems => lines.fold(0, (sum, l) => sum + l.quantity);

  int quantityOf(Product product) => lines
      .where((l) => l.product.id == product.id)
      .fold(0, (sum, l) => sum + l.quantity);

  /// Adds [delta] to [product]'s quantity, dropping the line at zero or below.
  Cart adjust(Product product, int delta) {
    final next = <CartLine>[];
    var found = false;

    for (final line in lines) {
      if (line.product.id != product.id) {
        next.add(line);
        continue;
      }
      found = true;
      final quantity = line.quantity + delta;
      if (quantity > 0) {
        next.add(CartLine(product: product, quantity: quantity));
      }
    }

    if (!found && delta > 0) {
      next.add(CartLine(product: product, quantity: delta));
    }

    return Cart(next);
  }

  List<TransactionItem> toTransactionItems() =>
      lines.map((l) => l.toTransactionItem()).toList();

  @override
  List<Object?> get props => [lines];
}
