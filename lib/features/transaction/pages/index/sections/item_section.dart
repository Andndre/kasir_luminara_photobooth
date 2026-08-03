part of '../page.dart';

class _ItemSection extends StatelessWidget {
  final Transaksi transaksi;
  final VoidCallback onDelete;

  const _ItemSection({required this.transaksi, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd/MM/yyyy • HH:mm');

    // Generate products summary
    final String productSummary = transaksi.items
        .map((e) => e.productName)
        .join(', ');

    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.dp12),
      child: AppCard(
        onTap: () => _showTransactionDetail(context),
        padding: const EdgeInsets.all(Dimens.dp12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaksi.queueNumber != null) ...[
              // Lingkaran: tidak menempel di sudut kartu, jadi tidak perlu
              // radius konsentris — dan tint lebih menyatu daripada blok pekat.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surfaces.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${transaksi.queueNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: Dimens.dp12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          transaksi.customerName ?? 'Pelanggan',
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Dimens.dp8),
                      Text(
                        formatter.format(transaksi.totalPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    productSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Dimens.dp8),
                  Row(
                    children: [
                      StatusBadge(transaksi.status),
                      const SizedBox(width: Dimens.dp8),
                      Expanded(
                        child: Text(
                          '${transaksi.paymentMethod} · ${dateFormatter.format(transaksi.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: surfaces.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    final dateFormatter = DateFormat('dd/MM/yyyy • HH:mm');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Transaksi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (transaksi.queueNumber != null)
                Text(
                  'Antrian: #${transaksi.queueNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              Text('Kode: ${transaksi.uuid}'),
              if (transaksi.midtransOrderId != null)
                Text(
                  'Order ID: ${transaksi.midtransOrderId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              Text('Nama: ${transaksi.customerName}'),
              Text('Metode: ${transaksi.paymentMethod}'),
              Text('Status: ${transaksi.status}'),
              Text('Dibuat: ${dateFormatter.format(transaksi.createdAt)}'),
              if (transaksi.redeemedAt != null)
                Text(
                  'Digunakan: ${dateFormatter.format(transaksi.redeemedAt!)}',
                ),
              const Divider(height: 24),
              const Text(
                'Item Pesanan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...transaksi.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${item.productName} x${item.quantity}'),
                      ),
                      Text(formatter.format(item.productPrice * item.quantity)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatter.format(transaksi.totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              if (transaksi.paymentMethod.toUpperCase() == 'TUNAI' &&
                  transaksi.bayarAmount != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bayar'),
                    Text(formatter.format(transaksi.bayarAmount)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembali'),
                    Text(formatter.format(transaksi.kembalian ?? 0)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: QrImageView(
                    data: transaksi.uuid,
                    version: QrVersions.auto,
                    size: 150.0,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
          TextButton(
            onPressed: () async {
              final result = await PrinterHelper.printPhotoboothTicket(
                uuid: transaksi.uuid,
                customerName: transaksi.customerName ?? '-',
                items: transaksi.items,
                totalPrice: transaksi.totalPrice,
                paymentMethod: transaksi.paymentMethod,
                date: transaksi.createdAt,
                bayarAmount: transaksi.bayarAmount,
                kembalian: transaksi.kembalian,
                queueNumber: transaksi.queueNumber,
              );

              if (context.mounted) {
                if (result) {
                  SnackBarHelper.showSuccess(context, 'Tiket berhasil dicetak');
                } else {
                  SnackBarHelper.showError(
                    context,
                    'Gagal mencetak tiket. Pastikan printer terhubung.',
                  );
                }
              }
            },
            child: const Text('Cetak Tiket'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
