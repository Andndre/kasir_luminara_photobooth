import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Kasir extends StatefulWidget {
  const Kasir({super.key});

  @override
  State<Kasir> createState() => _KasirState();
}

class _KasirState extends State<Kasir> {
  final TextEditingController _nameController = TextEditingController();
  // Cart state: Map<ProductID, Quantity>
  final Map<int, int> _cart = {};
  List<Produk> _products = [];
  bool _isLoading = true;
  String _paymentMethod = 'TUNAI';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await Produk.getAllProduk();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  int get _totalPrice {
    int total = 0;
    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((p) => p.id == productId);
      total += product.price * quantity;
    });
    return total;
  }

  void _updateQuantity(int productId, int delta) {
    setState(() {
      final currentQty = _cart[productId] ?? 0;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Transaksi Photobooth')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Product Selection
                        Expanded(
                          flex: 2,
                          child: _buildProductSection(),
                        ),
                        const SizedBox(width: 32),
                        // Right: Checkout & Details
                        SizedBox(
                          width: 450,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Dimens.radius),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: _buildCheckoutSection(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildProductSection()),
                        const SizedBox(height: 16),
                        _buildCheckoutSection(),
                      ],
                    ),
            ),
    );
  }

  Widget _buildProductSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Paket Photobooth',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final quantity = _cart[product.id] ?? 0;
              final isSelected = quantity > 0;

              return Card(
                elevation: isSelected ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 12),
                color: isSelected
                    ? theme.primaryColor.withValues(alpha: 0.1)
                    : theme.cardTheme.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Dimens.radius),
                  side: BorderSide(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(product.price),
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quantity Controls
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _updateQuantity(product.id!, -1),
                            color: isSelected ? theme.primaryColor : Colors.grey,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 30),
                            child: Text(
                              '$quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _updateQuantity(product.id!, 1),
                            color: theme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutSection() {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Pelanggan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Nama (Opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Metode Pembayaran',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'TUNAI', label: Text('TUNAI'), icon: Icon(Icons.money)),
              ButtonSegment(
                  value: 'QRIS', label: Text('QRIS'), icon: Icon(Icons.qr_code)),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _paymentMethod = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Ringkasan Pesanan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Belum ada produk dipilih',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            )
          else
            ..._cart.entries.map((entry) {
              final product = _products.firstWhere((p) => p.id == entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${product.name} x${entry.value}'),
                    ),
                    Text(currencyFormat.format(product.price * entry.value)),
                  ],
                ),
              );
            }),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL PEMBAYARAN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                currencyFormat.format(_totalPrice),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Dimens.radius),
                ),
              ),
              child: const Text(
                'BAYAR & CETAK TIKET',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _processPayment() async {
    if (_cart.isEmpty) return;

    final uuid = Transaksi.generateUuid();
    
    // Prepare items list
    List<TransaksiItem> items = [];
    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((p) => p.id == productId);
      items.add(TransaksiItem(
        productName: product.name,
        productPrice: product.price,
        quantity: quantity,
      ));
    });

    final transaction = Transaksi(
      uuid: uuid,
      customerName:
          _nameController.text.isEmpty ? 'Pelanggan' : _nameController.text,
      items: items,
      totalPrice: _totalPrice,
      paymentMethod: _paymentMethod,
      createdAt: DateTime.now(),
    );

    try {
      await Transaksi.createTransaksi(transaction);

      // Broadcast via WebSocket
      ServerService().broadcast('REFRESH_QUEUE');

      // Print Ticket
      final printResult = await PrinterHelper.printPhotoboothTicket(
        uuid: transaction.uuid,
        customerName: transaction.customerName ?? '-',
        items: transaction.items,
        totalPrice: transaction.totalPrice,
        paymentMethod: transaction.paymentMethod,
        date: transaction.createdAt,
      );

      if (!mounted) return;

      if (!printResult) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal mencetak tiket, pastikan printer terhubung')),
        );
      }

      // Show Success Dialog with Ticket QR
      _showTicketDialog(transaction);

      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showTicketDialog(Transaksi transaction) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Berhasil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Berikan tiket ini kepada pelanggan.'),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: transaction.uuid,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'TOTAL: ${currencyFormat.format(transaction.totalPrice)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Pelanggan: ${transaction.customerName}',
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            ...transaction.items.map((item) => Text(
                  '${item.productName} x${item.quantity}',
                  style: const TextStyle(fontSize: 12),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Back to dashboard
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}