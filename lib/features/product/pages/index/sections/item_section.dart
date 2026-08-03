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
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(Dimens.dp12),
      child: Row(
        children: [
          // Monogram yang sama dengan di layar Kasir — satu paket punya satu
          // warna di seluruh aplikasi.
          PackageMonogram(product.name, size: 44),
          const SizedBox(width: Dimens.dp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(product.price),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: surfaces.textSecondary,
            tooltip: 'Ubah',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppTokens.danger,
            tooltip: 'Hapus',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
