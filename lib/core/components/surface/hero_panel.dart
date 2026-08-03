import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';

/// Panel gradien wine. **Maksimal satu per layar** — kalau ada dua, keduanya
/// berhenti terasa penting.
///
/// [label] tampil sebagai eyebrow emas (uppercase, renggang), [value] sebagai
/// angka besar. Gold hanya dipakai untuk teks kecil, tidak pernah sebagai
/// ujung gradien.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.label,
    required this.value,
    this.meta,
    this.icon,
    this.trailing,
    this.gradient,
  });

  final String label;
  final String value;
  final String? meta;
  final IconData? icon;
  final Widget? trailing;

  /// Override untuk state non-brand (mis. verifier terputus).
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimens.dp20),
      decoration: BoxDecoration(
        gradient: gradient ?? AppTokens.heroGradient(theme.brightness),
        borderRadius: BorderRadius.circular(Dimens.rXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1412).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EyebrowText(label, color: AppTokens.accent400),
                const SizedBox(height: Dimens.dp8),
                Text(
                  value,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: Dimens.dp4),
                  Text(
                    meta!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (icon != null)
            Icon(icon, color: Colors.white.withValues(alpha: 0.28), size: 44),
        ],
      ),
    );
  }
}

/// Label section bergaya editorial: UPPERCASE, renggang, emas.
/// Menggantikan judul tebal biasa ("Kinerja Hari Ini").
class EyebrowText extends StatelessWidget {
  const EyebrowText(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? AppTokens.accent600,
        letterSpacing: 2.4, // .22em pada 11px, mengikuti .catalog-eyebrow
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
