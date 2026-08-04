import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/domain/transaction_status.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';

/// Badge status transaksi. Selalu tint + teks, tidak pernah fill jenuh.
///
/// PAID = menunggu dilayani (amber), COMPLETED = selesai (hijau).
/// Sengaja dibalik dari versi lama yang bikin PAID hijau padahal belum beres.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    final (Color bg, Color fg) = switch (status) {
      TransactionStatus.paid => (surfaces.warningTint, surfaces.onWarningTint),
      TransactionStatus.completed => (
        surfaces.successTint,
        surfaces.onSuccessTint,
      ),
      TransactionStatus.cancelled => (
        surfaces.dangerTint,
        surfaces.onDangerTint,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.dp8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Dimens.rXs),
      ),
      child: Text(
        status.dbValue,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: fg, letterSpacing: 0.6),
      ),
    );
  }
}

/// Monogram paket — pengganti thumbnail. Warnanya tetap untuk nama yang sama.
class PackageMonogram extends StatelessWidget {
  const PackageMonogram(this.name, {super.key, this.size = 44});

  final String name;
  final double size;

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.packageAccent(name);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.12,
        ),
        borderRadius: BorderRadius.circular(Dimens.rSm),
      ),
      child: Text(
        initials(name),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
