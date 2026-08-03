import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
import 'package:luminara_photobooth/core/services/midtrans_service.dart';
import 'package:luminara_photobooth/core/components/payment_webview_launcher.dart';
import 'package:luminara_photobooth/core/preferences/settings_preferences.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';

/// Kartu paket. Produk tidak punya foto, jadi identitasnya dipikul monogram
/// berwarna tetap (lihat [PackageMonogram]) dan harganya, bukan thumbnail.
class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Produk product;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final selected = quantity > 0;
    final accent = AppTokens.packageAccent(product.name);

    return AppCard(
      padding: const EdgeInsets.all(Dimens.dp12),
      borderColor: selected ? accent : surfaces.border,
      color: selected
          ? Color.alphaBlend(
              accent.withValues(alpha: 0.06),
              theme.colorScheme.surface,
            )
          : null,
      onTap: selected ? null : () => onChanged(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackageMonogram(product.name, size: 40),
          const SizedBox(height: Dimens.dp8),
          Expanded(
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(product.price),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Dimens.dp8),
          _QtyStepper(
            quantity: quantity,
            accent: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Stepper qty. Saat 0 hanya tombol "Tambah" selebar penuh — target sentuh
/// lebih besar daripada tiga kontrol kecil yang berdesakan.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.accent,
    required this.onChanged,
  });

  final int quantity;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    if (quantity == 0) {
      return SizedBox(
        height: 36,
        width: double.infinity,
        child: TextButton(
          onPressed: () => onChanged(1),
          style: TextButton.styleFrom(
            backgroundColor: surfaces.surfaceAlt,
            foregroundColor: surfaces.textSecondary,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Tambah'),
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.rFull),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            color: accent,
            onTap: () => onChanged(-1),
          ),
          Text(
            '$quantity',
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            color: accent,
            onTap: () => onChanged(1),
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: filled ? Colors.white : color),
      ),
    );
  }
}

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
  String _search = '';

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Flag untuk safety pop
  bool _isWebViewOpen = false;
  bool _isMidtransEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _checkPaymentSettings();
  }

  Future<void> _checkPaymentSettings() async {
    final enabled = await SettingsPreferences.isMidtransEnabled();
    setState(() {
      _isMidtransEnabled = enabled;
    });
  }

  Future<void> _loadProducts() async {
    final products = await Produk.getAllProduk();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _resetState() {
    setState(() {
      _cart.clear();
      _nameController.clear();
      _paymentMethod = 'TUNAI';
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

  int get _totalItems => _cart.values.fold(0, (sum, qty) => sum + qty);

  List<Produk> get _visibleProducts {
    if (_search.isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Baru')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildProductSection()),
                            const SizedBox(width: Dimens.dp24),
                            // Panel checkout menempel di kanan, tidak ikut
                            // scroll bersama daftar paket.
                            SizedBox(
                              width: 460,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  Dimens.dp20,
                                  Dimens.dp20,
                                  Dimens.dp20,
                                ),
                                child: _buildCheckoutSection(),
                              ),
                            ),
                          ],
                        )
                      : _buildProductSection(),
                ),
              ),
      ),
      bottomNavigationBar: (isDesktop || _isLoading) ? null : _buildCartBar(),
    );
  }

  Widget _buildProductSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.dp20,
            Dimens.dp16,
            Dimens.dp20,
            Dimens.dp12,
          ),
          child: SearchTextInput(
            hintText: 'Cari paket...',
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _visibleProducts.isEmpty
              ? Center(
                  child: Text(
                    _products.isEmpty
                        ? 'Belum ada paket. Tambahkan di menu Produk.'
                        : 'Paket tidak ditemukan.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Dimens.dp20,
                    0,
                    Dimens.dp20,
                    Dimens.dp20,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        crossAxisSpacing: Dimens.dp12,
                        mainAxisSpacing: Dimens.dp12,
                        mainAxisExtent: 168,
                      ),
                  itemCount: _visibleProducts.length,
                  itemBuilder: (context, index) {
                    final product = _visibleProducts[index];
                    return _PackageCard(
                      product: product,
                      quantity: _cart[product.id] ?? 0,
                      onChanged: (delta) => _updateQuantity(product.id!, delta),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Bar ringkas di bawah layar mobile. Detail checkout dibuka sebagai sheet
  /// supaya daftar paket tidak berbagi ruang dengan form panjang.
  Widget _buildCartBar() {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final isEmpty = _cart.isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Dimens.dp16,
        Dimens.dp12,
        Dimens.dp16,
        Dimens.dp12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: surfaces.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEmpty ? 'Belum ada paket dipilih' : '$_totalItems item',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  _currency.format(_totalPrice),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimens.dp16),
          ElevatedButton(
            onPressed: isEmpty ? null : _openCheckoutSheet,
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  void _openCheckoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        // Sheet punya elemen yang bisa diubah (metode bayar), jadi butuh
        // setter sendiri — setState induk tidak merebuild isi sheet.
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            Dimens.dp20,
            0,
            Dimens.dp20,
            Dimens.dp20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _buildCheckoutSection(refresh: setSheetState),
        ),
      ),
    );
  }

  Widget _buildCheckoutSection({StateSetter? refresh}) {
    final theme = Theme.of(context);

    void update(VoidCallback fn) {
      setState(fn);
      refresh?.call(() {});
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroPanel(
            label: 'Total Pembayaran',
            value: _currency.format(_totalPrice),
            meta: _cart.isEmpty
                ? 'Belum ada paket dipilih'
                : '$_totalItems item · ${_paymentMethod == 'TUNAI' ? 'Tunai' : 'Non-tunai'}',
          ),
          const SizedBox(height: Dimens.dp24),

          const EyebrowText('Nama Pelanggan'),
          const SizedBox(height: Dimens.dp8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Opsional'),
          ),
          const SizedBox(height: Dimens.dp24),

          const EyebrowText('Metode Pembayaran'),
          const SizedBox(height: Dimens.dp12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 'TUNAI',
                  label: Text('TUNAI'),
                  icon: Icon(Icons.payments_outlined, size: 18),
                ),
                ButtonSegment(
                  // Value tetap QRIS untuk konsistensi, label NON-TUNAI.
                  value: 'QRIS',
                  label: Text('NON-TUNAI'),
                  icon: Icon(Icons.qr_code_rounded, size: 18),
                ),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) =>
                  update(() => _paymentMethod = s.first),
            ),
          ),
          const SizedBox(height: Dimens.dp24),

          const EyebrowText('Ringkasan Pesanan'),
          const SizedBox(height: Dimens.dp12),
          if (_cart.isEmpty)
            Text('Belum ada paket dipilih', style: theme.textTheme.bodyMedium)
          else
            ..._cart.entries.map((entry) {
              final product = _products.firstWhere((p) => p.id == entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: Dimens.dp8),
                child: Row(
                  children: [
                    PackageMonogram(product.name, size: 32),
                    const SizedBox(width: Dimens.dp12),
                    Expanded(
                      child: Text(
                        '${product.name} ×${entry.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      _currency.format(product.price * entry.value),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: Dimens.dp24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _cart.isEmpty
                  ? null
                  : () {
                      // Tutup sheet dulu supaya dialog pembayaran tidak
                      // menumpuk di atasnya.
                      if (refresh != null) Navigator.pop(context);
                      _processPayment();
                    },
              child: Text(
                _paymentMethod == 'TUNAI' ? 'BAYAR' : 'BAYAR & CETAK TIKET',
                style: const TextStyle(fontSize: 15),
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
      _executePayment(
        totalBayar: _totalPrice,
        customerName: _nameController.text.isEmpty
            ? null
            : _nameController.text,
      );
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

            final surfaces = context.surfaces;

            return AlertDialog(
              title: const Text('Pembayaran Tunai'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Dimens.dp16),
                        decoration: BoxDecoration(
                          color: surfaces.brandTint,
                          borderRadius: BorderRadius.circular(Dimens.rLg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const EyebrowText('Total Tagihan'),
                            const SizedBox(height: Dimens.dp4),
                            Text(
                              currencyFormat.format(total),
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: Dimens.dp24),
                      const EyebrowText('Uang Diterima'),
                      const SizedBox(height: Dimens.dp12),

                      // Saran nominal
                      Wrap(
                        spacing: Dimens.dp8,
                        runSpacing: Dimens.dp8,
                        children: suggestions.map((amt) {
                          final isSelected = selectedAmount == amt;
                          return GestureDetector(
                            onTap: () => setDialogState(() {
                              selectedAmount = amt;
                              manualController.text = amt.toString();
                              manualController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: manualController.text.length,
                                    ),
                                  );
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimens.dp16,
                                vertical: Dimens.dp10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : surfaces.surfaceAlt,
                                borderRadius: BorderRadius.circular(
                                  Dimens.rFull,
                                ),
                              ),
                              child: Text(
                                currencyFormat.format(amt),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : surfaces.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: Dimens.dp16),
                      TextField(
                        controller: manualController,
                        keyboardType: TextInputType.number,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setDialogState(() {
                              manualController.clear();
                              selectedAmount = 0;
                            }),
                          ),
                        ),
                        onChanged: (val) {
                          final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                          setDialogState(() {
                            selectedAmount = int.tryParse(clean) ?? 0;
                          });
                        },
                      ),

                      const SizedBox(height: Dimens.dp20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimens.dp16,
                          vertical: Dimens.dp12,
                        ),
                        decoration: BoxDecoration(
                          color: isEnough
                              ? surfaces.successTint
                              : surfaces.dangerTint,
                          borderRadius: BorderRadius.circular(Dimens.rMd),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEnough ? 'Kembalian' : 'Uang kurang',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isEnough
                                    ? surfaces.onSuccessTint
                                    : surfaces.onDangerTint,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Text(
                                currencyFormat.format(kembalian.abs()),
                                key: ValueKey(kembalian),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: isEnough
                                      ? surfaces.onSuccessTint
                                      : surfaces.onDangerTint,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: !isEnough
                      ? null // Disable jika uang kurang
                      : () {
                          Navigator.pop(context);
                          _executePayment(
                            totalBayar: selectedAmount,
                            kembalian: kembalian,
                            customerName: _nameController.text.isEmpty
                                ? null
                                : _nameController.text,
                          );
                        },
                  child: const Text('BAYAR & CETAK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _executePayment({
    required int totalBayar,
    int kembalian = 0,
    String? customerName,
  }) async {
    if (_paymentMethod == 'QRIS') {
      if (_isMidtransEnabled) {
        // Online Flow (Midtrans)
        await _handleQrisPayment(totalBayar, customerName);
      } else {
        // Offline Flow (Manual Transfer/EDC Terpisah)
        // Langsung finalize dengan metode NON-TUNAI
        _finalizeTransaction(
          totalBayar: totalBayar,
          kembalian: 0,
          isQris: false, // False agar tidak trigger pop webview
          actualPaymentMethod: 'NON-TUNAI',
        );
      }
      return;
    }

    // Flow Tunai (Langsung Finalize)
    _finalizeTransaction(totalBayar: totalBayar, kembalian: kembalian);
  }

  Future<void> _handleQrisPayment(int amount, String? customerName) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = MidtransService();
      final response = await service.createTransaction(amount, customerName);

      if (!mounted) return;
      Navigator.pop(context); // Dismiss Loading

      final redirectUrl = response['redirect_url'];
      final orderId = response['order_id'];

      debugPrint(
        "🔗 LINK PEMBAYARAN MIDTRANS: $redirectUrl",
      ); // <--- KLIK LINK INI DI TERMINAL
      debugPrint("💳 ORDER ID: $orderId");

      // Launch WebView
      _isWebViewOpen = true;
      PaymentWebViewLauncher.launch(
        context,
        redirectUrl,
        onClose: () {
          _isWebViewOpen = false;
          debugPrint("WebView closed manually");
        },
      );

      // Start Polling
      _startPaymentPolling(orderId, amount);
    } catch (e) {
      Log.insertLog('Gagal inisiasi pembayaran: $e', isError: true);
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
        if (mounted) {
          SnackBarHelper.showError(context, 'Pembayaran Gagal/Kadaluarsa');
        }
      }
    });
  }

  String _normalizePaymentMethod(String? rawType) {
    if (rawType == null) return 'QRIS';

    // Mapping Midtrans Technical Name -> User Friendly Name
    switch (rawType) {
      case 'qris':
        return 'QRIS';
      case 'gopay':
        return 'GoPay/GoPay Later';
      case 'shopeepay':
        return 'ShopeePay/SPayLater';
      case 'akulaku':
        return 'Akulaku Paylater';
      case 'kredivo':
        return 'Kredivo';

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

      default:
        return 'QRIS ($rawType)';
    }
  }

  void _finalizeTransaction({
    required int totalBayar,
    int kembalian = 0,
    bool isQris = false,
    String? midtransOrderId,
    String? actualPaymentMethod,
  }) async {
    // Safety Close WebView jika masih terbuka
    if (isQris) {
      // Mobile: Pop Dialog
      if (_isWebViewOpen && (Platform.isAndroid || Platform.isIOS)) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _isWebViewOpen = false;
      }

      // Windows/macOS: Close Window Programmatically
      // Note: This is skipped for Linux in the helper itself to prevent crashes.
      PaymentWebViewLauncher.close();
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
      paymentMethod:
          actualPaymentMethod ?? _paymentMethod, // USE ACTUAL IF AVAILABLE
      createdAt: DateTime.now(),
      midtransOrderId: midtransOrderId,
    );

    try {
      final queueNumber = await Transaksi.createTransaksi(transaction);

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
        queueNumber: queueNumber,
        openDrawer: transaction.paymentMethod.toUpperCase() == 'TUNAI',
      );

      if (!mounted) return;

      // OLD CODE REMOVED: Safety pop is now handled at start of function

      if (!printResult) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak tiket, pastikan printer terhubung'),
          ),
        );
      }

      // Show Success Dialog with Ticket QR
      _showTicketDialog(transaction, totalBayar, kembalian, queueNumber);

      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      Log.insertLog('Gagal menyimpan transaksi: $e', isError: true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showTicketDialog(Transaksi transaction, int totalBayar, int kembalian, int queueNumber) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final surfaces = context.surfaces;

        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(
            Dimens.dp24,
            Dimens.dp24,
            Dimens.dp24,
            Dimens.dp8,
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaces.successTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: surfaces.onSuccessTint,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: Dimens.dp16),

                  // Nomor antrean adalah informasi terpenting di layar ini.
                  const EyebrowText('Nomor Antrean'),
                  Text(
                    '$queueNumber',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    transaction.customerName ?? 'Pelanggan',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Dimens.dp20),

                  // QR WAJIB di atas putih murni — QR gelap tidak terbaca
                  // scanner, termasuk saat aplikasi dalam mode gelap.
                  Container(
                    padding: const EdgeInsets.all(Dimens.dp12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Dimens.rLg),
                      border: Border.all(color: surfaces.border),
                    ),
                    child: QrImageView(
                      data: transaction.uuid,
                      version: QrVersions.auto,
                      size: 168,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: Dimens.dp8),
                  Text(
                    transaction.uuid,
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: Dimens.dp20),

                  _SummaryRow(
                    'Total',
                    currencyFormat.format(transaction.totalPrice),
                    strong: true,
                  ),
                  if (_paymentMethod == 'TUNAI') ...[
                    _SummaryRow('Bayar', currencyFormat.format(totalBayar)),
                    _SummaryRow(
                      'Kembali',
                      currencyFormat.format(kembalian),
                      strong: true,
                    ),
                  ],
                  const SizedBox(height: Dimens.dp12),
                  Divider(color: surfaces.border),
                  const SizedBox(height: Dimens.dp8),
                  ...transaction.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimens.dp4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} ×${item.quantity}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.dp8),
                  Text(
                    'Berikan tiket ini kepada pelanggan.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup dialog saja
                  _resetState(); // Reset data kasir untuk transaksi berikutnya
                },
                child: const Text('Selesai'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (strong ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.dp4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(value, style: style),
        ],
      ),
    );
  }
}
