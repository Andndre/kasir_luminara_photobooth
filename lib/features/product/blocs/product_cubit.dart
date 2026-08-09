import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/sync_service.dart';

class ProductListState extends Equatable {
  final AsyncState<List<Product>> products;
  final String query;

  const ProductListState({
    this.products = const AsyncLoading(),
    this.query = '',
  });

  /// Filtering is derived, not stored — the old screen kept `products` and
  /// `filteredProducts` as two fields that could disagree after an edit.
  List<Product> get visible {
    final all = products.dataOrNull ?? const <Product>[];
    if (query.isEmpty) return all;
    final needle = query.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(needle)).toList();
  }

  bool get isSearching => query.isNotEmpty;

  ProductListState copyWith({
    AsyncState<List<Product>>? products,
    String? query,
  }) => ProductListState(
    products: products ?? this.products,
    query: query ?? this.query,
  );

  @override
  List<Object?> get props => [products, query];
}

class ProductCubit extends Cubit<ProductListState> {
  ProductCubit({ProductRepository repository = const ProductRepository()})
    : _repository = repository,
      super(const ProductListState());

  final ProductRepository _repository;

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(products: AsyncLoading(state.products.dataOrNull)));
    final result = await _repository.all();
    if (!isClosed) emit(state.copyWith(products: result.toAsyncState()));
  }

  /// Pull-to-refresh: selaraskan dengan server dulu, baru baca ulang lokal.
  ///
  /// Returns null on success, or a message to show the user. Gagal terhubung
  /// bukan alasan menolak menampilkan katalog yang sudah ada di perangkat —
  /// [load] tetap dijalankan.
  Future<String?> refresh() async {
    final synced = await SyncService().refreshProducts();
    await load();
    return switch (synced) {
      Err(:final message) => message,
      Ok() => null,
    };
  }

  void search(String query) => emit(state.copyWith(query: query));

  /// Returns null on success, or a message to show the user.
  Future<String?> save(Product product) async {
    final result = product.id == null
        ? await _repository.create(product)
        : await _repository.update(product);

    if (result case Err(:final message)) return message;
    await load();
    return null;
  }

  Future<String?> delete(Product product) async {
    final id = product.id;
    if (id == null) return 'Produk belum tersimpan';

    if (await _repository.delete(id) case Err(:final message)) return message;
    await load();
    return null;
  }
}
