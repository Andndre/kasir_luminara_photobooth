import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/product/blocs/product_cubit.dart';
import 'package:luminara_photobooth/features/product/widgets/product_card.dart';
import 'package:luminara_photobooth/features/product/widgets/product_form_dialog.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductCubit()..load(),
      child: const _ProductView(),
    );
  }
}

class _ProductView extends StatefulWidget {
  const _ProductView();

  @override
  State<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends State<_ProductView> {
  @override
  void initState() {
    super.initState();
    // Reload after a backup restore replaces the database underneath us.
    dataRefresh.addListener(_reload);
  }

  @override
  void dispose() {
    dataRefresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) context.read<ProductCubit>().load();
  }

  Future<void> _openForm({Product? existing}) async {
    final cubit = context.read<ProductCubit>();
    final product = await ProductFormDialog.show(context, existing: existing);
    if (product == null) return;

    final error = await cubit.save(product);
    if (error != null && mounted) {
      SnackBarHelper.showError(context, error);
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final cubit = context.read<ProductCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Hapus paket "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppTokens.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await cubit.delete(product);
    if (mounted) {
      if (error != null) {
        SnackBarHelper.showError(context, error);
      } else {
        SnackBarHelper.showSuccess(context, 'Paket dihapus');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Paket Photobooth'),
        actions: [
          // Bukan FAB: slot FAB layar ini sudah dipakai tombol Kasir milik
          // MainPage, keduanya akan bertumpuk di pojok kanan bawah.
          Padding(
            padding: const EdgeInsets.only(right: Dimens.dp16),
            child: TextButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Tambah'),
              style: TextButton.styleFrom(
                backgroundColor: context.surfaces.brandTint,
                padding: const EdgeInsets.symmetric(horizontal: Dimens.dp16),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.dp20,
                Dimens.dp8,
                Dimens.dp20,
                Dimens.dp12,
              ),
              child: SearchTextInput(
                hintText: 'Cari paket...',
                onChanged: context.read<ProductCubit>().search,
              ),
            ),
            Expanded(
              child: BlocBuilder<ProductCubit, ProductListState>(
                builder: (context, state) => switch (state.products) {
                  AsyncLoading(previous: null) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  AsyncFailed(:final message) => EmptyState(
                    isError: true,
                    icon: Icons.inventory_2_outlined,
                    title: 'Gagal memuat paket',
                    message: message,
                    actionLabel: 'Coba Lagi',
                    onAction: () => context.read<ProductCubit>().load(),
                  ),
                  _ when state.visible.isEmpty => EmptyState(
                    icon: state.isSearching
                        ? Icons.search_off_rounded
                        : Icons.inventory_2_outlined,
                    title: state.isSearching
                        ? 'Paket tidak ditemukan'
                        : 'Belum ada paket',
                    message: state.isSearching
                        ? 'Coba kata kunci lain.'
                        : 'Tambahkan paket photobooth supaya bisa dijual di kasir.',
                    actionLabel: state.isSearching ? null : 'Tambah Paket',
                    onAction: state.isSearching ? null : _openForm,
                  ),
                  _ => _ProductList(
                    products: state.visible,
                    isDesktop: isDesktop,
                    onEdit: (p) => _openForm(existing: p),
                    onDelete: _confirmDelete,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.isDesktop,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final bool isDesktop;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;

  static const _padding = EdgeInsets.fromLTRB(
    Dimens.dp20,
    0,
    Dimens.dp20,
    Dimens.dp20,
  );

  @override
  Widget build(BuildContext context) {
    Widget cardAt(int index) {
      final product = products[index];
      return ProductCard(
        product: product,
        onEdit: () => onEdit(product),
        onDelete: () => onDelete(product),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ProductCubit>().load(),
      child: isDesktop
          ? GridView.builder(
              padding: _padding,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                crossAxisSpacing: Dimens.dp12,
                mainAxisSpacing: Dimens.dp12,
                mainAxisExtent: 76,
              ),
              itemCount: products.length,
              itemBuilder: (_, index) => cardAt(index),
            )
          : ListView.separated(
              padding: _padding,
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: Dimens.dp12),
              itemBuilder: (_, index) => cardAt(index),
            ),
    );
  }
}
