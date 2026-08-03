import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';

/// Kartu standar: ivory, garis rambut emas, bayangan tinta lembut.
///
/// Radiusnya [Dimens.rLg] dengan padding 16 — konsentris dengan elemen di
/// dalamnya yang memakai [Dimens.rSm] (24 - 16 = 8). Lihat DESIGN.md §4.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Dimens.dp16),
    this.onTap,
    this.borderColor,
    this.color,
    this.flat = false,
  });

  /// Tanpa bayangan — untuk kartu di dalam kartu.
  const AppCard.flat({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Dimens.dp16),
    this.onTap,
    this.borderColor,
    this.color,
  }) : flat = true;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final radius = BorderRadius.circular(Dimens.rLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? surfaces.border),
        boxShadow: flat ? const [] : surfaces.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
