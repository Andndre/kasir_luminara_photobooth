import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/settings_preferences.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

import 'cart.dart';

class CashierState extends Equatable {
  final AsyncState<List<Product>> products;
  final Cart cart;
  final String customerName;
  final PaymentMethod paymentMethod;
  final String query;

  /// Whether online (Midtrans) payment is switched on in Settings. When off,
  /// a non-cash sale is recorded without contacting Midtrans at all.
  final bool isMidtransEnabled;

  const CashierState({
    this.products = const AsyncLoading(),
    this.cart = const Cart(),
    this.customerName = '',
    this.paymentMethod = PaymentMethod.cash,
    this.query = '',
    this.isMidtransEnabled = false,
  });

  List<Product> get visibleProducts {
    final all = products.dataOrNull ?? const <Product>[];
    if (query.isEmpty) return all;
    final needle = query.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(needle)).toList();
  }

  bool get hasNoProducts => (products.dataOrNull ?? const []).isEmpty;

  CashierState copyWith({
    AsyncState<List<Product>>? products,
    Cart? cart,
    String? customerName,
    PaymentMethod? paymentMethod,
    String? query,
    bool? isMidtransEnabled,
  }) => CashierState(
    products: products ?? this.products,
    cart: cart ?? this.cart,
    customerName: customerName ?? this.customerName,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    query: query ?? this.query,
    isMidtransEnabled: isMidtransEnabled ?? this.isMidtransEnabled,
  );

  @override
  List<Object?> get props => [
    products,
    cart,
    customerName,
    paymentMethod,
    query,
    isMidtransEnabled,
  ];
}

/// Owns the checkout: catalogue, cart, and writing the sale.
///
/// Deliberately knows nothing about dialogs or navigation — the page decides
/// what to show, this decides what is true.
class CashierCubit extends Cubit<CashierState> {
  CashierCubit({
    ProductRepository products = const ProductRepository(),
    TransactionRepository transactions = const TransactionRepository(),
  }) : _products = products,
       _transactions = transactions,
       super(const CashierState());

  final ProductRepository _products;
  final TransactionRepository _transactions;
  static const _uuid = Uuid();

  Future<void> init() async {
    await Future.wait([loadProducts(), _loadPaymentSettings()]);
  }

  Future<void> loadProducts() async {
    if (isClosed) return;
    emit(state.copyWith(products: AsyncLoading(state.products.dataOrNull)));
    final result = await _products.all();
    if (!isClosed) emit(state.copyWith(products: result.toAsyncState()));
  }

  Future<void> _loadPaymentSettings() async {
    final enabled = await SettingsPreferences.isMidtransEnabled();
    if (!isClosed) emit(state.copyWith(isMidtransEnabled: enabled));
  }

  void search(String query) => emit(state.copyWith(query: query));

  void adjustQuantity(Product product, int delta) =>
      emit(state.copyWith(cart: state.cart.adjust(product, delta)));

  void setCustomerName(String name) => emit(state.copyWith(customerName: name));

  void setPaymentMethod(PaymentMethod method) =>
      emit(state.copyWith(paymentMethod: method));

  /// Clears the sale, ready for the next customer. Keeps the loaded catalogue.
  void reset() => emit(
    CashierState(
      products: state.products,
      isMidtransEnabled: state.isMidtransEnabled,
    ),
  );

  /// Writes the sale and returns the saved transaction, queue number included.
  ///
  /// [amountPaid] and [changeGiven] only apply to cash; [method] overrides the
  /// selected one when Midtrans reports the actual channel used.
  ///
  /// `syncWarning` is non-null when the sale is safely on disk but did not
  /// reach luminarabali.com — the ticket cannot be scanned from another device
  /// until it does, so the page must say so out loud.
  Future<Result<({Transaction transaction, String? syncWarning})>> checkout({
    required int amountPaid,
    int changeGiven = 0,
    PaymentMethod? method,
    String? midtransOrderId,
  }) async {
    final name = state.customerName.trim();
    final paymentMethod = method ?? state.paymentMethod;

    final transaction = Transaction(
      uuid: _uuid.v4(),
      customerName: name.isEmpty ? 'Pelanggan' : name,
      items: state.cart.toTransactionItems(),
      totalPrice: state.cart.totalPrice,
      amountPaid: amountPaid,
      changeGiven: changeGiven,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
      midtransOrderId: midtransOrderId,
    );

    final saved = await _transactions.create(transaction);
    if (saved case Err()) {
      return (saved as Err)
          .cast<({Transaction transaction, String? syncWarning})>();
    }

    final queueNumber = (saved as Ok<int>).value;

    // Ditunggu, bukan dilempar ke latar: pelanggan berjalan dari kasir ke booth
    // dalam hitungan detik, dan tiket yang belum sampai server tidak bisa
    // dipindai di sana. Kegagalannya dilaporkan, bukan membatalkan penjualan —
    // barisnya tetap `synced_at IS NULL` dan ikut terkirim di percobaan berikutnya.
    final String? syncWarning = AuthService().isLoggedIn
        ? switch (await SyncService().push()) {
            Err(:final message) => message,
            Ok() => null,
          }
        : null;

    return Ok((
      transaction: transaction.copyWith(
        queueNumber: queueNumber,
        queueDate: DateTime.now().toIso8601String().substring(0, 10),
      ),
      syncWarning: syncWarning,
    ));
  }
}
