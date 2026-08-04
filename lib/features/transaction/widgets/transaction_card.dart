import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';

/// One row in the history list.
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final Transaction transaction;
  final VoidCallback onTap;

  static final _dateFormat = DateFormat('dd/MM/yyyy • HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final queueNumber = transaction.queueNumber;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.dp12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Dimens.dp12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (queueNumber != null) ...[
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
                  '$queueNumber',
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
                          transaction.customerName ?? 'Pelanggan',
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Dimens.dp8),
                      Text(
                        Currency.format(transaction.totalPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.items.map((e) => e.productName).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Dimens.dp8),
                  Row(
                    children: [
                      StatusBadge(transaction.status),
                      const SizedBox(width: Dimens.dp8),
                      Expanded(
                        child: Text(
                          '${transaction.paymentMethod.dbValue} · '
                          '${_dateFormat.format(transaction.createdAt)}',
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
}
