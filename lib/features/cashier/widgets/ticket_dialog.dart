import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Success screen after a sale: queue number, QR, and the receipt summary.
class TicketDialog extends StatelessWidget {
  const TicketDialog({super.key, required this.transaction});

  final Transaction transaction;

  static Future<void> show(BuildContext context, Transaction transaction) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TicketDialog(transaction: transaction),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final amountPaid = transaction.amountPaid;

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
                '${transaction.queueNumber ?? '-'}',
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
                style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(height: Dimens.dp20),

              _SummaryRow(
                'Total',
                Currency.format(transaction.totalPrice),
                strong: true,
              ),
              if (transaction.paymentMethod.isCash && amountPaid != null) ...[
                _SummaryRow('Bayar', Currency.format(amountPaid)),
                _SummaryRow(
                  'Kembali',
                  Currency.format(transaction.changeGiven ?? 0),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ),
      ],
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
    final style =
        (strong ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
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
