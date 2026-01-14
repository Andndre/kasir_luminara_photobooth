part of '../page.dart';

class _ItemSection extends StatelessWidget {
  final Produk product;
  final VoidCallback onDelete;
  final String Function(int) formatCurrency;

  const _ItemSection({
    required this.product,
    required this.onDelete,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(formatCurrency(product.price)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}