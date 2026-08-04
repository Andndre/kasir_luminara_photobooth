import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

/// Kartu paket. Produk tidak punya foto, jadi identitasnya dipikul monogram
/// berwarna tetap (lihat [PackageMonogram]) dan harganya, bukan thumbnail.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Product product;
  final int quantity;

  /// Called with a delta (+1 / -1), not an absolute quantity.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final selected = quantity > 0;
    final accent = AppTokens.packageAccent(product.name);

    return AppCard(
      padding: const EdgeInsets.all(Dimens.dp12),
      borderColor: selected ? accent : surfaces.border,
      color: selected
          ? Color.alphaBlend(
              accent.withValues(alpha: 0.06),
              theme.colorScheme.surface,
            )
          : null,
      onTap: selected ? null : () => onChanged(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackageMonogram(product.name, size: 40),
          const SizedBox(height: Dimens.dp8),
          Expanded(
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            Currency.format(product.price),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Dimens.dp8),
          _QtyStepper(quantity: quantity, accent: accent, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Stepper qty. Saat 0 hanya tombol "Tambah" selebar penuh — target sentuh
/// lebih besar daripada tiga kontrol kecil yang berdesakan.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.accent,
    required this.onChanged,
  });

  final int quantity;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    if (quantity == 0) {
      return SizedBox(
        height: 36,
        width: double.infinity,
        child: TextButton(
          onPressed: () => onChanged(1),
          style: TextButton.styleFrom(
            backgroundColor: surfaces.surfaceAlt,
            foregroundColor: surfaces.textSecondary,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Tambah'),
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.rFull),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            color: accent,
            onTap: () => onChanged(-1),
          ),
          Text(
            '$quantity',
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            color: accent,
            onTap: () => onChanged(1),
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // Material + InkWell rather than GestureDetector: focus, keyboard
    // activation and a ripple come for free, and screen readers get a button.
    return Material(
      // Not Colors.transparent: that is black at alpha 0, which tints the
      // icon during the fade.
      color: filled ? color : color.withValues(alpha: 0),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: filled ? 'Tambah' : 'Kurangi',
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: filled ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}
