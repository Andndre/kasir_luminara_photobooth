import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

class ItemMenuSetting extends StatelessWidget {
  const ItemMenuSetting({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Function()? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.dp16,
          vertical: Dimens.dp12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: surfaces.textSecondary),
            Dimens.dp16.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right_rounded,
                color: surfaces.textMuted,
                size: Dimens.dp20,
              ),
          ],
        ),
      ),
    );
  }
}
