import 'package:equatable/equatable.dart';

/// A sellable package (e.g. "Self Photo 15 Menit").
///
/// Pure data — persistence lives in `ProductRepository`. [id] is null until the
/// row has been inserted.
class Product extends Equatable {
  final int? id;
  final String name;

  /// Rupiah, stored as a whole number of rupiah (no cents).
  final int price;

  const Product({this.id, required this.name, required this.price});

  /// Column names are frozen — see `products` table in `db.dart`.
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'price': price};

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    price: map['price'] as int,
  );

  Product copyWith({int? id, String? name, int? price}) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
  );

  @override
  List<Object?> get props => [id, name, price];
}
