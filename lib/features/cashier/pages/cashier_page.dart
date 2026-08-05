import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/components/payment_webview_launcher.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/cashier_lease_service.dart';
import 'package:luminara_photobooth/core/services/midtrans_service.dart';
import 'package:luminara_photobooth/features/cashier/blocs/cart.dart';
import 'package:luminara_photobooth/features/cashier/blocs/cashier_cubit.dart';
import 'package:luminara_photobooth/features/cashier/payment_poller.dart';
import 'package:luminara_photobooth/features/cashier/widgets/cash_payment_dialog.dart';
import 'package:luminara_photobooth/features/cashier/widgets/checkout_panel.dart';
import 'package:luminara_photobooth/features/cashier/widgets/package_card.dart';
import 'package:luminara_photobooth/features/cashier/widgets/ticket_dialog.dart';
import 'package:luminara_photobooth/features/settings/pages/printer_page.dart';

enum _PrinterAction { cancel, connect, continueAnyway }

class CashierPage extends StatelessWidget {
  const CashierPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CashierCubit()..init(),
      child: const _CashierView(),
    );
  }
}

class _CashierView extends StatefulWidget {
  const _CashierView();

  @override
  State<_CashierView> createState() => _CashierViewState();
}

class _CashierViewState extends State<_CashierView> {
  final _poller = PaymentPoller();
  bool _isWebViewOpen = false;

  /// Guards against a second sale being started while one is in flight. The
  /// desktop payment window is a separate OS window, so the "Bayar" button
  /// underneath stays clickable.
  bool _isPaying = false;

  @override
  void dispose() {
    // Without this the poll kept running after the screen was gone.
    _poller.cancel();
    // Same for the desktop payment window: leaving the screen while it is open
    // otherwise strands it.
    PaymentWebViewLauncher.close();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Payment flow
  // -------------------------------------------------------------------------

  /// Menahan penjualan kalau printer belum tersambung, dan menawarkan jalan
  /// keluarnya.
  ///
  /// Peringatannya harus datang SEBELUM uang diterima. Sebelum ini kasir baru
  /// tahu dari pesan "gagal mencetak" — saat transaksi sudah tersimpan dan
  /// pelanggan sudah berjalan ke booth tanpa tiket di tangan.
  ///
  /// Returns true kalau penjualan boleh diteruskan.
  Future<bool> _ensurePrinter() async {
    // Desktop tidak punya Bluetooth SPP di paket ini, jadi jawabannya selalu
    // "tidak terhubung" — memblokir kasir Windows karena itu jelas salah.
    if (!PrinterHelper.isSupported) return true;
    if (await PrinterHelper.isConnected) return true;
    if (!mounted) return false;

    final action = await showDialog<_PrinterAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Printer belum terhubung'),
        content: const Text(
          'Tiket tidak akan tercetak dan pelanggan tidak punya QR untuk '
          'dipindai di booth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PrinterAction.cancel),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PrinterAction.continueAnyway),
            child: const Text('Lanjut Tanpa Cetak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _PrinterAction.connect),
            child: const Text('Hubungkan'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return false;

    switch (action) {
      case _PrinterAction.cancel:
        return false;
      case _PrinterAction.continueAnyway:
        return true;
      case _PrinterAction.connect:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const PrinterPage()),
        );
        if (!mounted) return false;
        // Kembali tanpa printer tersambung berarti tetap batal — meneruskan
        // diam-diam persis mengulang masalah yang mau diperbaiki di sini.
        if (await PrinterHelper.isConnected) return true;
        if (mounted) {
          SnackBarHelper.showWarning(context, 'Printer masih belum terhubung');
        }
        return false;
    }
  }

  /// Menahan penjualan kalau perangkat ini bukan kasir yang berlaku.
  ///
  /// Di sinilah aturan "satu kasir per akun" benar-benar berlaku — sisanya cuma
  /// pembukuan. Dua perangkat yang sama-sama menjual berarti nomor antrian
  /// kembar dan setoran yang tidak bisa dicocokkan.
  Future<bool> _ensureCashierRole() async {
    final lease = CashierLeaseService();
    if (lease.state.canSell) return true;

    final holder = lease.holder;
    final takeOver = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perangkat ini bukan kasir'),
        content: Text(
          holder == null
              ? 'Peran kasir sudah diambil alih perangkat lain. Transaksi di '
                    'sini akan membuat nomor antrian kembar.'
              : 'Peran kasir sedang dipegang ${holder.deviceName}. Transaksi '
                    'di sini akan membuat nomor antrian kembar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
            child: const Text('Ambil Alih'),
          ),
        ],
      ),
    );

    if (takeOver != true || !mounted) return false;

    await lease.claim(force: true);
    if (!mounted) return false;

    if (!lease.state.canSell) {
      SnackBarHelper.showError(context, 'Gagal mengambil alih peran kasir');
      return false;
    }
    return true;
  }

  Future<void> _startPayment() async {
    if (_isPaying) return;
    final cubit = context.read<CashierCubit>();
    final state = cubit.state;
    if (state.cart.isEmpty) return;

    if (!await _ensureCashierRole()) return;
    if (!mounted) return;

    if (!await _ensurePrinter()) return;
    if (!mounted) return;

    _isPaying = true;
    try {
      if (state.paymentMethod.isCash) {
        final tendered = await CashPaymentDialog.show(
          context,
          state.cart.totalPrice,
        );
        if (tendered == null || !mounted) return;

        await _completeSale(
          amountPaid: tendered.amountPaid,
          changeGiven: tendered.changeGiven,
        );
        return;
      }

      // Non-cash. With Midtrans off, the money is taken on a separate device
      // and we just record the sale.
      if (!state.isMidtransEnabled) {
        await _completeSale(
          amountPaid: state.cart.totalPrice,
          method: PaymentMethod.nonCash,
        );
        return;
      }

      await _payWithMidtrans(state.cart.totalPrice);
    } finally {
      _isPaying = false;
    }
  }

  Future<void> _payWithMidtrans(int amount) async {
    final cubit = context.read<CashierCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final MidtransSession session;
    try {
      session = await MidtransService().createTransaction(
        amount,
        cubit.state.customerName.isEmpty ? null : cubit.state.customerName,
      );
    } catch (e) {
      AppLog.error('Gagal inisiasi pembayaran: $e');
      if (!mounted) return;
      navigator.pop(); // loading
      SnackBarHelper.showError(context, 'Gagal inisiasi pembayaran: $e');
      return;
    }

    if (!mounted) return;
    navigator.pop(); // loading

    _isWebViewOpen = true;
    PaymentWebViewLauncher.launch(
      context,
      session.redirectUrl,
      onClose: () => _isWebViewOpen = false,
    );

    final outcome = await _poller.start(session.orderId);
    if (!mounted) return;

    _closePaymentWebView();

    switch (outcome) {
      case PaymentSettled(:final paymentType):
        await _completeSale(
          amountPaid: amount,
          method: PaymentMethod.fromMidtrans(paymentType),
          midtransOrderId: session.orderId,
        );
      case PaymentDeclined(:final reason):
        messenger.showSnackBar(SnackBar(content: Text(reason)));
      case PaymentTimedOut():
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Pembayaran tidak selesai. Silakan coba lagi.'),
          ),
        );
      case PaymentAborted():
        break;
    }
  }

  void _closePaymentWebView() {
    if (_isWebViewOpen && (Platform.isAndroid || Platform.isIOS)) {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
    _isWebViewOpen = false;
    // Desktop window. No-op on Linux inside the helper, where closing it
    // programmatically crashes.
    PaymentWebViewLauncher.close();
  }

  Future<void> _completeSale({
    required int amountPaid,
    int changeGiven = 0,
    PaymentMethod? method,
    String? midtransOrderId,
  }) async {
    final cubit = context.read<CashierCubit>();

    final result = await cubit.checkout(
      amountPaid: amountPaid,
      changeGiven: changeGiven,
      method: method,
      midtransOrderId: midtransOrderId,
    );

    if (!mounted) return;

    switch (result) {
      case Err(:final message):
        AppLog.error(message);
        SnackBarHelper.showError(context, message);

      case Ok(value: (transaction: final transaction, :final syncWarning)):
        // Penjualan sudah aman di disk. Kalau belum sampai server, kasir harus
        // tahu sekarang — tiketnya belum bisa dipindai dari perangkat lain.
        if (syncWarning != null) {
          SnackBarHelper.showWarning(
            context,
            'Tiket belum terkirim ke server: $syncWarning',
          );
        }

        // The sale is saved at this point; a failed print must not lose it.
        final printed = await PrinterHelper.printTicket(
          transaction,
          openDrawer: transaction.paymentMethod.isCash,
        );
        if (!mounted) return;

        if (!printed) {
          SnackBarHelper.showError(
            context,
            'Gagal mencetak tiket, pastikan printer terhubung',
          );
        }

        HapticFeedback.heavyImpact();
        await TicketDialog.show(context, transaction);
        if (!mounted) return;
        cubit.reset();
    }
  }

  void _openCheckoutSheet() {
    final cubit = context.read<CashierCubit>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: Padding(
          // paddingOf, bukan viewPaddingOf: yang pertama sudah nol saat keyboard
          // menutupi bilah navigasi, jadi keduanya tidak pernah dijumlah dua kali.
          padding: EdgeInsets.fromLTRB(
            Dimens.dp20,
            0,
            Dimens.dp20,
            Dimens.dp20 +
                MediaQuery.viewInsetsOf(sheetContext).bottom +
                MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: CheckoutPanel(
            onPay: () {
              // Close the sheet first so the payment dialog isn't stacked on it.
              Navigator.pop(sheetContext);
              _startPayment();
            },
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Layout
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return BlocBuilder<CashierCubit, CashierState>(
      builder: (context, state) {
        final isLoading =
            state.products is AsyncLoading && state.products.dataOrNull == null;

        return Scaffold(
          appBar: AppBar(title: const Text('Transaksi Baru')),
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _ProductSection(state: state)),
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
                                    child: CheckoutPanel(onPay: _startPayment),
                                  ),
                                ),
                              ],
                            )
                          : _ProductSection(state: state),
                    ),
                  ),
          ),
          bottomNavigationBar: (isDesktop || isLoading)
              ? null
              : _CartBar(cart: state.cart, onContinue: _openCheckoutSheet),
        );
      },
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.state});

  final CashierState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashierCubit>();
    final visible = state.visibleProducts;

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
            onChanged: cubit.search,
          ),
        ),
        Expanded(
          child: switch (state.products) {
            AsyncFailed(:final message) => EmptyState(
              isError: true,
              icon: Icons.inventory_2_outlined,
              title: 'Gagal memuat paket',
              message: message,
              actionLabel: 'Coba Lagi',
              onAction: cubit.loadProducts,
            ),
            _ when visible.isEmpty => EmptyState(
              icon: state.hasNoProducts
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              title: state.hasNoProducts
                  ? 'Belum ada paket'
                  : 'Paket tidak ditemukan',
              message: state.hasNoProducts
                  ? 'Tambahkan paket di menu Produk supaya bisa dijual.'
                  : 'Coba kata kunci lain.',
            ),
            _ => GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                Dimens.dp20,
                0,
                Dimens.dp20,
                Dimens.dp20,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                crossAxisSpacing: Dimens.dp12,
                mainAxisSpacing: Dimens.dp12,
                mainAxisExtent: 168,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final product = visible[index];
                return PackageCard(
                  product: product,
                  quantity: state.cart.quantityOf(product),
                  onChanged: (delta) => cubit.adjustQuantity(product, delta),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}

/// Bar ringkas di bawah layar mobile. Detail checkout dibuka sebagai sheet
/// supaya daftar paket tidak berbagi ruang dengan form panjang.
class _CartBar extends StatelessWidget {
  const _CartBar({required this.cart, required this.onContinue});

  final Cart cart;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

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
                  cart.isEmpty
                      ? 'Belum ada paket dipilih'
                      : '${cart.totalItems} item',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  Currency.format(cart.totalPrice),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimens.dp16),
          ElevatedButton(
            onPressed: cart.isEmpty ? null : onContinue,
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }
}
