import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/model/produk.dart';

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
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.primary,
              size: 28,
            ),
            onPressed: () async {
              _showAddProductDialog();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchTextInput(
              hintText: 'Cari paket...',
              onChanged: _searchProducts,
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredProducts.isEmpty
                    ? const Center(child: Text('Tidak ada paket.'))
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: isDesktop
                            ? GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 130,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return _ItemSection(
                                    product: product,
                                    onDelete: () => _deleteProduct(product),
                                    formatCurrency: _formatCurrency,
                                  );
                                },
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16.0),
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return _ItemSection(
                                    product: product,
                                    onDelete: () => _deleteProduct(product),
                                    formatCurrency: _formatCurrency,
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemCount: filteredProducts.length,
                              ),
                      ),
          ),
        ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
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

  void _deleteProduct(Produk product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Hapus paket "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await Produk.deleteProduk(product.id!);
              
              if (!mounted) return;
              navigator.pop();
              _loadProducts();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}