import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';

/// Snackbar bergaya tint, bukan fill jenuh — sewarna dengan badge status
/// di layar lain. Bentuk dan radius diambil dari `snackBarTheme`.
class SnackBarHelper {
  static void showSuccess(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.check_circle_outline,
    accent: AppTokens.success,
    duration: const Duration(seconds: 3),
  );

  static void showWarning(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.warning_amber_rounded,
    accent: AppTokens.warning,
    duration: const Duration(seconds: 4),
  );

  static void showError(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.error_outline,
    accent: AppTokens.danger,
    duration: const Duration(seconds: 5),
  );

  static void showInfo(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.info_outline,
    accent: AppTokens.accent600,
    duration: const Duration(seconds: 3),
  );

  static void showCustom(
    BuildContext context,
    String message, {
    Color backgroundColor = AppTokens.accent600,
    IconData icon = Icons.notifications_outlined,
    Duration duration = const Duration(seconds: 3),
  }) => _show(
    context,
    message,
    icon: icon,
    accent: backgroundColor,
    duration: duration,
  );

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color accent,
    required Duration duration,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      // Snackbar yang menumpuk bikin pesan penting tertahan di antrean.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: Dimens.dp12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
