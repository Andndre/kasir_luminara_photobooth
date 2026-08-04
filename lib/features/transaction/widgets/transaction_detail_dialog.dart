import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Baris label–nilai. Label redup, nilai kontras penuh.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.dp4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// What the user gets back from the detail dialog. `null` means they just
/// closed it.
enum TransactionDetailAction { delete }

class TransactionDetailDialog extends StatelessWidget {
  const TransactionDetailDialog({super.key, required this.transaction});

  final Transaction transaction;

  static final _dateFormat = DateFormat('dd/MM/yyyy • HH:mm');

  static Future<TransactionDetailAction?> show(
    BuildContext context,
    Transaction transaction,
  ) => showDialog<TransactionDetailAction>(
    context: context,
    builder: (_) => TransactionDetailDialog(transaction: transaction),
  );

  Future<void> _print(BuildContext context) async {
    final printed = await PrinterHelper.printTicket(transaction);
    if (!context.mounted) return;

    if (printed) {
      SnackBarHelper.showSuccess(context, 'Tiket berhasil dicetak');
    } else {
      SnackBarHelper.showError(
        context,
        'Gagal mencetak tiket. Pastikan printer terhubung.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queueNumber = transaction.queueNumber;
    final amountPaid = transaction.amountPaid;

    return AlertDialog(
      title: const Text('Detail Transaksi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (queueNumber != null) ...[
              const EyebrowText('Nomor Antrean'),
              Text(
                '$queueNumber',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: Dimens.dp12),
            ],
            _DetailRow('Kode', transaction.uuid),
            if (transaction.midtransOrderId != null)
              _DetailRow('Order ID', transaction.midtransOrderId!),
            _DetailRow('Nama', transaction.customerName ?? 'Pelanggan'),
            _DetailRow('Metode', transaction.paymentMethod.label),
            _DetailRow('Status', transaction.status.label),
            _DetailRow('Dibuat', _dateFormat.format(transaction.createdAt)),
            if (transaction.redeemedAt != null)
              _DetailRow(
                'Digunakan',
                _dateFormat.format(transaction.redeemedAt!),
              ),
            const Divider(height: Dimens.dp24),
            const EyebrowText('Item Pesanan'),
            const SizedBox(height: Dimens.dp8),
            ...transaction.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item.productName} x${item.quantity}'),
                    ),
                    Text(Currency.format(item.subtotal)),
                  ],
                ),
              ),
            ),
            const Divider(height: Dimens.dp24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  Currency.format(transaction.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTokens.brand600,
                  ),
                ),
              ],
            ),
            if (transaction.paymentMethod.isCash && amountPaid != null) ...[
              const SizedBox(height: Dimens.dp8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bayar'),
                  Text(Currency.format(amountPaid)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembali'),
                  Text(Currency.format(transaction.changeGiven ?? 0)),
                ],
              ),
            ],
            const SizedBox(height: Dimens.dp24),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: QrImageView(
                  data: transaction.uuid,
                  version: QrVersions.auto,
                  size: 150,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(Dimens.dp12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, TransactionDetailAction.delete),
          style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
          child: const Text('Hapus'),
        ),
        TextButton(
          onPressed: () => _print(context),
          child: const Text('Cetak Tiket'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
