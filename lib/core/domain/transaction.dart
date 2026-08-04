import 'package:equatable/equatable.dart';

import 'payment_method.dart';
import 'transaction_status.dart';

/// One line on a receipt. Product name and price are snapshotted at sale time
/// so editing a product later never rewrites history.
class TransactionItem extends Equatable {
  final int? id;
  final String productName;
  final int productPrice;
  final int quantity;

  const TransactionItem({
    this.id,
    required this.productName,
    required this.productPrice,
    required this.quantity,
  });

  int get subtotal => productPrice * quantity;

  /// Column names are frozen — see `transaction_items` table in `db.dart`.
  Map<String, Object?> toMap(String transactionUuid) => {
    'transaction_uuid': transactionUuid,
    'product_name': productName,
    'product_price': productPrice,
    'quantity': quantity,
  };

  factory TransactionItem.fromMap(Map<String, Object?> map) => TransactionItem(
    id: map['id'] as int?,
    productName: map['product_name'] as String,
    productPrice: map['product_price'] as int,
    quantity: map['quantity'] as int,
  );

  TransactionItem copyWith({int? quantity}) => TransactionItem(
    id: id,
    productName: productName,
    productPrice: productPrice,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [id, productName, productPrice, quantity];
}

/// A completed sale — the ticket a customer redeems at the booth.
///
/// Pure data; persistence lives in `TransactionRepository`. Note this shadows
/// sqflite's `Transaction`; files that need both import sqflite with
/// `hide Transaction`.
class Transaction extends Equatable {
  final String uuid;
  final String? customerName;
  final List<TransactionItem> items;
  final int totalPrice;

  /// Cash handed over. Null for non-cash payments.
  final int? amountPaid;

  /// Change given back. Null for non-cash payments.
  final int? changeGiven;

  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? midtransOrderId;

  /// Assigned by the repository at insert time; null only before persisting.
  final int? queueNumber;

  /// `yyyy-MM-dd` the queue number belongs to — counters reset daily.
  final String? queueDate;

  const Transaction({
    required this.uuid,
    this.customerName,
    required this.items,
    required this.totalPrice,
    this.amountPaid,
    this.changeGiven,
    this.paymentMethod = PaymentMethod.cash,
    this.status = TransactionStatus.paid,
    required this.createdAt,
    this.redeemedAt,
    this.midtransOrderId,
    this.queueNumber,
    this.queueDate,
  });

  /// Column names and the persisted enum strings are frozen —
  /// see `transactions` table in `db.dart`.
  Map<String, Object?> toMap() => {
    'uuid': uuid,
    'customer_name': customerName,
    'total_price': totalPrice,
    'bayar_amount': amountPaid,
    'kembalian': changeGiven,
    'payment_method': paymentMethod.dbValue,
    'status': status.dbValue,
    'created_at': createdAt.toIso8601String(),
    'redeemed_at': redeemedAt?.toIso8601String(),
    'midtrans_order_id': midtransOrderId,
    'queue_number': queueNumber,
    'queue_date': queueDate,
  };

  factory Transaction.fromMap(
    Map<String, Object?> map,
    List<TransactionItem> items,
  ) => Transaction(
    uuid: map['uuid'] as String,
    customerName: map['customer_name'] as String?,
    items: items,
    totalPrice: map['total_price'] as int? ?? 0,
    amountPaid: map['bayar_amount'] as int?,
    changeGiven: map['kembalian'] as int?,
    paymentMethod: PaymentMethod.fromDb(map['payment_method'] as String?),
    status: TransactionStatus.fromDb(map['status'] as String?),
    createdAt: DateTime.parse(map['created_at'] as String),
    redeemedAt: map['redeemed_at'] != null
        ? DateTime.parse(map['redeemed_at'] as String)
        : null,
    midtransOrderId: map['midtrans_order_id'] as String?,
    queueNumber: map['queue_number'] as int?,
    queueDate: map['queue_date'] as String?,
  );

  Transaction copyWith({
    int? queueNumber,
    String? queueDate,
    TransactionStatus? status,
    DateTime? redeemedAt,
  }) => Transaction(
    uuid: uuid,
    customerName: customerName,
    items: items,
    totalPrice: totalPrice,
    amountPaid: amountPaid,
    changeGiven: changeGiven,
    paymentMethod: paymentMethod,
    status: status ?? this.status,
    createdAt: createdAt,
    redeemedAt: redeemedAt ?? this.redeemedAt,
    midtransOrderId: midtransOrderId,
    queueNumber: queueNumber ?? this.queueNumber,
    queueDate: queueDate ?? this.queueDate,
  );

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  List<Object?> get props => [
    uuid,
    customerName,
    items,
    totalPrice,
    amountPaid,
    changeGiven,
    paymentMethod,
    status,
    createdAt,
    redeemedAt,
    midtransOrderId,
    queueNumber,
    queueDate,
  ];
}
