import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';

/// Layar kosong / error. Ikon dalam lingkaran tint, judul, satu baris
/// penjelasan, dan (opsional) satu aksi. Dipakai untuk keduanya supaya
/// "tidak ada data" dan "gagal memuat" terasa satu keluarga.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    final tint = isError ? surfaces.dangerTint : surfaces.surfaceAlt;
    final fg = isError ? surfaces.onDangerTint : surfaces.textMuted;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimens.dp24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: fg),
              ),
              const SizedBox(height: Dimens.dp20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: Dimens.dp8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Dimens.dp24),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
