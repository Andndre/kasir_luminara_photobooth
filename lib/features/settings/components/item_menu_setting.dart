import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

class ItemMenuSetting extends StatelessWidget {
  const ItemMenuSetting({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Function()? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.dp16,
          vertical: Dimens.dp12,
        ),
        child: Row(
          children: [
            Icon(icon, color: context.theme.iconTheme.color),
            Dimens.dp12.width,
            Expanded(
              child: RegularText.medium(
                title,
                style: const TextStyle(fontSize: Dimens.dp14),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: context.theme.primaryColor,
                size: Dimens.dp16,
              ),
          ],
        ),
      ),
    );
  }
}
