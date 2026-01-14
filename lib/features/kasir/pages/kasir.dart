import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
import 'package:luminara_photobooth/core/helpers/printer.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Kasir extends StatefulWidget {
  const Kasir({super.key});

  @override
  State<Kasir> createState() => _KasirState();
}

class _KasirState extends State<Kasir> {
  final TextEditingController _nameController = TextEditingController();
  Produk? _selectedProduct;
  List<Produk> _products = [];
  bool _isLoading = true;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Photobooth')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Pelanggan (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan nama...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pilih Paket Photobooth',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final isSelected = _selectedProduct?.id == product.id;
                        return Card(
                          color: isSelected ? Colors.blue.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Colors.blue : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            title: Text(product.name),
                            trailing: Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(product.price),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedProduct = product;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedProduct == null ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('BAYAR & CETAK TIKET', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _processPayment() async {
    if (_selectedProduct == null) return;

    final uuid = Transaksi.generateUuid();
    final transaction = Transaksi(
      uuid: uuid,
      customerName: _nameController.text.isEmpty ? 'Pelanggan' : _nameController.text,
      productName: _selectedProduct!.name,
      productPrice: _selectedProduct!.price,
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
        productName: transaction.productName,
        price: transaction.productPrice,
        date: transaction.createdAt,
      );

      if (!mounted) return;

      if (!printResult) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mencetak tiket, pastikan printer terhubung')),
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
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${transaction.productName}\n${transaction.customerName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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