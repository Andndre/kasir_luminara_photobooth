part of '../page.dart';

class _ItemSection extends StatelessWidget {
  final Transaksi transaksi;
  final VoidCallback onDelete;

  const _ItemSection({
    required this.transaksi,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    final dateFormatter = DateFormat('dd/MM/yyyy • HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimens.radius)),
      child: ListTile(
        title: Text(transaksi.customerName ?? 'Pelanggan'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaksi.productName),
            Text(dateFormatter.format(transaksi.createdAt)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(transaksi.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                transaksi.status,
                style: TextStyle(
                  color: _getStatusColor(transaksi.status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          formatter.format(transaksi.productPrice),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
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
        title: const Text('Detail Tiket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UUID: ${transaksi.uuid}'),
            Text('Nama: ${transaksi.customerName}'),
            Text('Paket: ${transaksi.productName}'),
            Text('Harga: ${formatter.format(transaksi.productPrice)}'),
            Text('Status: ${transaksi.status}'),
            Text('Dibuat: ${dateFormatter.format(transaksi.createdAt)}'),
            if (transaksi.redeemedAt != null)
              Text('Digunakan: ${dateFormatter.format(transaksi.redeemedAt!)}'),
            const SizedBox(height: 16),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
