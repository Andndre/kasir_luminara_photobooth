import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/cashier/blocs/cashier_cubit.dart';

/// Customer name, payment method, order summary and the pay button.
///
/// Same widget on desktop (docked right) and mobile (inside a bottom sheet);
/// [onPay] is what differs — the sheet closes itself first.
class CheckoutPanel extends StatefulWidget {
  const CheckoutPanel({super.key, required this.onPay});

  final VoidCallback onPay;

  @override
  State<CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<CheckoutPanel> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<CashierCubit>().state.customerName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CashierCubit, CashierState>(
      // Keep the field in step when the cubit resets after a completed sale.
      listenWhen: (a, b) => a.customerName != b.customerName,
      listener: (context, state) {
        if (_nameController.text != state.customerName) {
          _nameController.text = state.customerName;
        }
      },
      builder: (context, state) {
        final cubit = context.read<CashierCubit>();
        final cart = state.cart;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroPanel(
                label: 'Total Pembayaran',
                value: Currency.format(cart.totalPrice),
                meta: cart.isEmpty
                    ? 'Belum ada paket dipilih'
                    : '${cart.totalItems} item · ${state.paymentMethod.label}',
              ),
              const SizedBox(height: Dimens.dp24),

              const EyebrowText('Nama Pelanggan'),
              const SizedBox(height: Dimens.dp8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Opsional'),
                onChanged: cubit.setCustomerName,
              ),
              const SizedBox(height: Dimens.dp24),

              const EyebrowText('Metode Pembayaran'),
              const SizedBox(height: Dimens.dp12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PaymentMethod>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: PaymentMethod.cash,
                      label: Text('TUNAI'),
                      icon: Icon(Icons.payments_outlined, size: 18),
                    ),
                    ButtonSegment(
                      // Disimpan sebagai QRIS, ditampilkan NON-TUNAI.
                      value: PaymentMethod.qris,
                      label: Text('NON-TUNAI'),
                      icon: Icon(Icons.qr_code_rounded, size: 18),
                    ),
                  ],
                  selected: {state.paymentMethod},
                  onSelectionChanged: (s) => cubit.setPaymentMethod(s.first),
                ),
              ),
              const SizedBox(height: Dimens.dp24),

              const EyebrowText('Ringkasan Pesanan'),
              const SizedBox(height: Dimens.dp12),
              if (cart.isEmpty)
                Text(
                  'Belum ada paket dipilih',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ...cart.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: Dimens.dp8),
                    child: Row(
                      children: [
                        PackageMonogram(line.product.name, size: 32),
                        const SizedBox(width: Dimens.dp12),
                        Expanded(
                          child: Text(
                            '${line.product.name} ×${line.quantity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          Currency.format(line.subtotal),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: Dimens.dp24),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : widget.onPay,
                  child: Text(
                    state.paymentMethod.isCash
                        ? 'BAYAR'
                        : 'BAYAR & CETAK TIKET',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
