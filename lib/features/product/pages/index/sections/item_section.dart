part of '../page.dart';

class _ItemSection extends StatelessWidget {
  final Produk product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(int) formatCurrency;

  const _ItemSection({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radius)),
      child: ListTile(
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(formatCurrency(product.price)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}