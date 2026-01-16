import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
import 'package:luminara_photobooth/core/services/midtrans_service.dart';
import 'package:luminara_photobooth/core/components/payment_webview_launcher.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async'; // Added for Timer

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
  
  // Flag untuk safety pop
  bool _isWebViewOpen = false;

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
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Product Selection
                          Expanded(flex: 2, child: _buildProductSection()),
                          const SizedBox(width: 32),
                          // Right: Checkout & Details
                          SizedBox(
                            width: 450,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimens.radius,
                                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.grey,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 30),
                            child: Text(
                              '$quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: theme.primaryColor,
              selectedForegroundColor: Colors.white,
            ),
            segments: const [
              ButtonSegment(
                value: 'TUNAI',
                label: Text('TUNAI'),
                icon: Icon(Icons.money),
              ),
              ButtonSegment(
                value: 'QRIS',
                label: Text('QRIS'),
                icon: Icon(Icons.qr_code),
              ),
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
              child: Text(
                'Belum ada produk dipilih',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ..._cart.entries.map((entry) {
              final product = _products.firstWhere((p) => p.id == entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${product.name} x${entry.value}')),
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
              child: Text(
                _paymentMethod == 'TUNAI' ? 'BAYAR' : 'BAYAR & CETAK TIKET',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _processPayment() async {
    if (_cart.isEmpty) return;

    if (_paymentMethod == 'TUNAI') {
      _showCashDialog();
    } else {
      _executePayment(totalBayar: _totalPrice);
    }
  }

  void _showCashDialog() {
    final theme = Theme.of(context);
    final int total = _totalPrice;

    // Format mata uang
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final manualController = TextEditingController();

    // --- LOGIKA CERDAS SARAN NOMINAL ---
    Set<int> suggestionSet = {total}; // Selalu masukkan uang pas

    // Daftar pecahan uang kertas umum di Indonesia
    List<int> fractions = [5000, 10000, 20000, 50000, 100000];

    for (var f in fractions) {
      // Jika total belanja lebih kecil dari pecahan (misal belanja 3.000, pecahan 5.000)
      // Maka masukkan pecahan tersebut
      if (total < f) {
        suggestionSet.add(f);
      } else {
        // Jika lebih besar, cari kelipatan terdekat di atasnya
        // Rumus: (Total / pecahan) dibulatkan ke atas * pecahan
        // Contoh: Belanja 12.000. Pecahan 10.000.
        // 12k/10k = 1.2 -> ceil jadi 2 -> 2 * 10k = 20.000
        int rounded = ((total / f).ceil() * f).toInt();
        if (rounded > total) {
          suggestionSet.add(rounded);
        }
      }
    }

    // Urutkan dan ambil maksimal 6 opsi agar UI tidak penuh
    List<int> suggestions = suggestionSet.toList();
    suggestions.sort();
    suggestions = suggestions.take(6).toList();
    // -----------------------------------

    showDialog(
      context: context,
      builder: (context) {
        // State lokal untuk dialog
        int selectedAmount = total;

        // Inisialisasi awal controller text
        if (manualController.text.isEmpty) {
          manualController.text = total.toString();
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int kembalian = selectedAmount - total;
            final bool isEnough = selectedAmount >= total;

            return AlertDialog(
              title: const Text('Pembayaran Tunai'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tampilan Total
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Tagihan',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            currencyFormat.format(total),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Pilih Uang Tunai:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Suggestion Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((amt) {
                        final isSelected = selectedAmount == amt;
                        return ChoiceChip(
                          label: Text(
                            currencyFormat.format(amt),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: theme.primaryColor,
                          backgroundColor: Colors.grey.shade200,
                          checkmarkColor: Colors.white,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedAmount = amt;
                                // Update text field saat chip dipilih
                                manualController.text = amt.toString();
                                // Pindahkan kursor ke akhir
                                manualController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(
                                        offset: manualController.text.length,
                                      ),
                                    );
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Input Manual (Rp):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Text Input
                    TextField(
                      controller: manualController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setDialogState(() {
                              manualController.clear();
                              selectedAmount = 0;
                            });
                          },
                        ),
                      ),
                      onChanged: (val) {
                        // Hapus karakter non-digit jika ada
                        String cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                        int newVal = int.tryParse(cleanVal) ?? 0;

                        setDialogState(() {
                          selectedAmount = newVal;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Info Kembalian
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kembalian:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          currencyFormat.format(kembalian),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kembalian < 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (!isEnough)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Uang kurang ${currencyFormat.format(total - selectedAmount)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: !isEnough
                      ? null // Disable jika uang kurang
                      : () {
                          Navigator.pop(context);
                          _executePayment(
                            totalBayar: selectedAmount,
                            kembalian: kembalian,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        theme.primaryColor, // Ganti AppColors.primary
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('BAYAR & CETAK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _executePayment({required int totalBayar, int kembalian = 0}) async {
    if (_paymentMethod == 'QRIS') {
      await _handleQrisPayment(totalBayar);
      return;
    }

    // Flow Tunai (Langsung Finalize)
    _finalizeTransaction(totalBayar: totalBayar, kembalian: kembalian);
  }

  Future<void> _handleQrisPayment(int amount) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = MidtransService();
      final response = await service.createTransaction(amount);

      if (!mounted) return;
      Navigator.pop(context); // Dismiss Loading

      final redirectUrl = response['redirect_url'];
      final orderId = response['order_id'];

      debugPrint("🔗 LINK PEMBAYARAN MIDTRANS: $redirectUrl"); // <--- KLIK LINK INI DI TERMINAL
      debugPrint("💳 ORDER ID: $orderId");

      // Launch WebView
      _isWebViewOpen = true;
      PaymentWebViewLauncher.launch(
        context,
        redirectUrl,
        onClose: () {
           _isWebViewOpen = false;
           debugPrint("WebView closed manually");
        }
      );

      // Start Polling
      _startPaymentPolling(orderId, amount);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss Loading if error
        SnackBarHelper.showError(context, 'Gagal inisiasi pembayaran: $e');
      }
    }
  }

  void _startPaymentPolling(String orderId, int amount) {
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final service = MidtransService();
      
      // FORCE SYNC: Paksa Laravel cek ke Midtrans (karena Webhook tidak jalan di localhost)
      await service.syncTransaction(orderId);

      final result = await service.checkStatus(orderId);
      final status = result['status'];
      final rawPaymentType = result['payment_type'];

      if (status == 'paid' || status == 'settlement') {
        timer.cancel();
        
        if (mounted) {
             // Finalize
             _finalizeTransaction(
               totalBayar: amount, 
               kembalian: 0, 
               isQris: true,
               midtransOrderId: orderId,
               actualPaymentMethod: _normalizePaymentMethod(rawPaymentType),
             );
        }
      } else if (status == 'failed' || status == 'expire') {
        timer.cancel();
        if (mounted) SnackBarHelper.showError(context, 'Pembayaran Gagal/Kadaluarsa');
      }
    });
  }

  String _normalizePaymentMethod(String? rawType) {
    if (rawType == null) return 'QRIS';
    
    // Mapping Midtrans Technical Name -> User Friendly Name
    switch (rawType) {
      case 'qris': return 'QRIS';
      case 'gopay': return 'GoPay/GoPay Later';
      case 'shopeepay': return 'ShopeePay/SPayLater';
      case 'akulaku': return 'Akulaku Paylater';
      case 'kredivo': return 'Kredivo';
      
      // Virtual Accounts / Bank Transfer
      case 'bank_transfer': 
      case 'echannel': // Mandiri Bill
      case 'permata_va':
      case 'bca_va':
      case 'bni_va':
      case 'bri_va':
      case 'cimb_va':
      case 'other_va':
        return 'Bank Transfer (VA)';
        
      default: return 'QRIS ($rawType)';
    }
  }

  void _finalizeTransaction({
    required int totalBayar, 
    int kembalian = 0, 
    bool isQris = false,
    String? midtransOrderId,
    String? actualPaymentMethod, // NEW: Metode pembayaran asli dari Midtrans
  }) async {
    // Safety Close WebView jika masih terbuka (khusus Mobile)
    if (isQris && _isWebViewOpen && (Platform.isAndroid || Platform.isIOS)) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _isWebViewOpen = false;
    }

    final uuid = Transaksi.generateUuid();

    // Prepare items list
    List<TransaksiItem> items = [];
    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((p) => p.id == productId);
      items.add(
        TransaksiItem(
          productName: product.name,
          productPrice: product.price,
          quantity: quantity,
        ),
      );
    });

    final transaction = Transaksi(
      uuid: uuid,
      customerName: _nameController.text.isEmpty
          ? 'Pelanggan'
          : _nameController.text,
      items: items,
      totalPrice: _totalPrice,
      bayarAmount: totalBayar,
      kembalian: kembalian,
      paymentMethod: actualPaymentMethod ?? _paymentMethod, // USE ACTUAL IF AVAILABLE
      createdAt: DateTime.now(),
      midtransOrderId: midtransOrderId,
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
        bayarAmount: totalBayar,
        kembalian: kembalian,
        date: transaction.createdAt,
      );

            if (!mounted) return;
            
            // OLD CODE REMOVED: Safety pop is now handled at start of function
      
            if (!printResult) {        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak tiket, pastikan printer terhubung'),
          ),
        );
      }

      // Show Success Dialog with Ticket QR
      _showTicketDialog(transaction, totalBayar, kembalian);

      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showTicketDialog(Transaksi transaction, int totalBayar, int kembalian) {
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
            if (_paymentMethod == 'TUNAI') ...[
              Text('Bayar: ${currencyFormat.format(totalBayar)}'),
              Text(
                'Kembali: ${currencyFormat.format(kembalian)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
            ],
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
            ...transaction.items.map(
              (item) => Text(
                '${item.productName} x${item.quantity}',
                style: const TextStyle(fontSize: 12),
              ),
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
