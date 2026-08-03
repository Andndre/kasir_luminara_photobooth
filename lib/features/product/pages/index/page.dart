import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:provider/provider.dart';

part 'sections/item_section.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<Produk> products = [];
  List<Produk> filteredProducts = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();

    // Listen untuk refresh setelah restore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    // Cleanup listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().removeListener(_onAppStateChanged);
      }
    });
    super.dispose();
  }

  void _onAppStateChanged() {
    // Refresh products saat AppState memberi signal
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    try {
      final productList = await Produk.getAllProduk();
      setState(() {
        products = productList;
        filteredProducts = productList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        Log.insertLog('Error loading products: $e', isError: true);
        SnackBarHelper.showError(context, 'Error loading products: $e');
      }
    }
  }

  void _searchProducts(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((product) {
          final name = product.name.toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower);
        }).toList();
      }
    });
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final theme = Theme.of(context);

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
              onPressed: _showAddProductDialog,
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
                onChanged: _searchProducts,
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredProducts.isEmpty
                  ? EmptyState(
                      icon: searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.inventory_2_outlined,
                      title: searchQuery.isNotEmpty
                          ? 'Paket tidak ditemukan'
                          : 'Belum ada paket',
                      message: searchQuery.isNotEmpty
                          ? 'Coba kata kunci lain.'
                          : 'Tambahkan paket photobooth supaya bisa dijual di kasir.',
                      actionLabel: searchQuery.isEmpty ? 'Tambah Paket' : null,
                      onAction: searchQuery.isEmpty
                          ? _showAddProductDialog
                          : null,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: isDesktop
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                Dimens.dp20,
                                0,
                                Dimens.dp20,
                                Dimens.dp20,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 420,
                                    crossAxisSpacing: Dimens.dp12,
                                    mainAxisSpacing: Dimens.dp12,
                                    mainAxisExtent: 76,
                                  ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return _ItemSection(
                                  product: product,
                                  onEdit: () => _showEditProductDialog(product),
                                  onDelete: () => _deleteProduct(product),
                                  formatCurrency: _formatCurrency,
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                Dimens.dp20,
                                0,
                                Dimens.dp20,
                                Dimens.dp20,
                              ),
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return _ItemSection(
                                  product: product,
                                  onEdit: () => _showEditProductDialog(product),
                                  onDelete: () => _deleteProduct(product),
                                  formatCurrency: _formatCurrency,
                                );
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: Dimens.dp12),
                              itemCount: filteredProducts.length,
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Paket Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Paket'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Harga (Rp)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                final p = Produk(
                  name: nameController.text,
                  price: int.parse(priceController.text),
                );

                final navigator = Navigator.of(context);
                await Produk.createProduk(p);

                if (!mounted) return;
                navigator.pop();
                _loadProducts();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Produk product) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(
      text: product.price.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Paket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Paket'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Harga (Rp)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                final p = Produk(
                  id: product.id,
                  name: nameController.text,
                  price: int.parse(priceController.text),
                );

                final navigator = Navigator.of(context);
                await Produk.updateProduk(p);

                if (!mounted) return;
                navigator.pop();
                _loadProducts();
              }
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(Produk product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Hapus paket "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await Produk.deleteProduk(product.id!);

              if (!mounted) return;
              navigator.pop();
              _loadProducts();
            },
            child: const Text('Hapus', style: TextStyle(color: AppTokens.danger)),
          ),
        ],
      ),
    );
  }
}
