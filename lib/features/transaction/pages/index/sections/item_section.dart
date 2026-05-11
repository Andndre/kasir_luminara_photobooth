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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.radius),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: transaksi.queueNumber != null
            ? CircleAvatar(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: Text('#${transaksi.queueNumber}'),
              )
            : null,
        title: Text(
          transaksi.customerName ?? 'Pelanggan',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            Text(
              dateFormatter.format(transaksi.createdAt),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      transaksi.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaksi.status,
                    style: TextStyle(
                      color: _getStatusColor(transaksi.status),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  transaksi.paymentMethod,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          formatter.format(transaksi.totalPrice),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
        onTap: () {
          _showTransactionDetail(context);
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
