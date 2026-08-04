import 'package:equatable/equatable.dart';

import 'transaction.dart';

/// A ticket as it travels over the local network between the cashier (server)
/// and the verifier (client), via `GET /api/queue`.
///
/// The JSON keys are a wire contract: a verifier running an older build may be
/// on the same network, so [toJson] keeps emitting every key the old
/// map-based client read. Add keys freely; never rename or remove one.
class QueueTicket extends Equatable {
  final String uuid;
  final String customerName;
  final int? queueNumber;
  final DateTime? createdAt;
  final List<QueueTicketItem> items;

  const QueueTicket({
    required this.uuid,
    required this.customerName,
    this.queueNumber,
    this.createdAt,
    this.items = const [],
  });

  factory QueueTicket.fromTransaction(Transaction transaction) => QueueTicket(
    uuid: transaction.uuid,
    customerName: transaction.customerName ?? 'Pelanggan',
    queueNumber: transaction.queueNumber,
    createdAt: transaction.createdAt,
    items: transaction.items
        .map(
          (i) =>
              QueueTicketItem(productName: i.productName, quantity: i.quantity),
        )
        .toList(),
  );

  /// One-line "Paket A (x2), Paket B (x1)" summary. Sent as `product_name` for
  /// older verifier builds that render a single string instead of the list.
  String get summary => items.isEmpty
      ? '-'
      : items.map((i) => '${i.productName} (x${i.quantity})').join(', ');

  Map<String, Object?> toJson() => {
    'uuid': uuid,
    'customer_name': customerName,
    'queue_number': queueNumber,
    'created_at': createdAt?.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'product_name': summary,
  };

  factory QueueTicket.fromJson(Map<String, dynamic> json) => QueueTicket(
    uuid: json['uuid'] as String? ?? '',
    customerName: json['customer_name'] as String? ?? 'Pelanggan',
    queueNumber: json['queue_number'] as int?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((i) => QueueTicketItem.fromJson(i.cast<String, dynamic>()))
        .toList(),
  );

  @override
  List<Object?> get props => [
    uuid,
    customerName,
    queueNumber,
    createdAt,
    items,
  ];
}

class QueueTicketItem extends Equatable {
  final String productName;
  final int quantity;

  const QueueTicketItem({required this.productName, required this.quantity});

  Map<String, Object?> toJson() => {
    'product_name': productName,
    'quantity': quantity,
  };

  factory QueueTicketItem.fromJson(Map<String, dynamic> json) =>
      QueueTicketItem(
        productName: json['product_name'] as String? ?? '-',
        quantity: json['quantity'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [productName, quantity];
}
