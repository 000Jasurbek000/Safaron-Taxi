import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';

class SafaronHeader extends StatelessWidget {
  const SafaronHeader({
    super.key,
    this.trailing,
    this.onBack,
    this.subtitle = "Har safar ishonchli yo'l",
    this.showHome = false,
  });

  final Widget? trailing;
  final VoidCallback? onBack;
  final String subtitle;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          AppBackButton(onTap: onBack),
          const Spacer(),
          if (trailing != null) trailing! else const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
