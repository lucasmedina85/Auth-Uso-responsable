import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

enum BadgeStatus {
  success,
  warning,
  error,
  critical,
  pending,
  verified,
  blocked,
  info
}

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final bool outlined;

  const StatusBadge({
    super.key,
    required this.text,
    required this.status,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color getStatusColor() {
      switch (status) {
        case BadgeStatus.success:
        case BadgeStatus.verified:
          return isDark ? AppColorsDark.success : AppColorsLight.success;
        case BadgeStatus.warning:
        case BadgeStatus.pending:
          return isDark ? AppColorsDark.warning : AppColorsLight.warning;
        case BadgeStatus.error:
          return isDark ? AppColorsDark.error : AppColorsLight.error;
        case BadgeStatus.critical:
        case BadgeStatus.blocked:
          return isDark ? AppColorsDark.critical : AppColorsLight.critical;
        case BadgeStatus.info:
          return isDark ? AppColorsDark.secondary : AppColorsLight.secondary;
      }
    }

    final color = getStatusColor();
    final backgroundColor = outlined ? Colors.transparent : color.withOpacity(0.1);
    final borderColor = outlined ? color : Colors.transparent;
    final textColor = color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing12,
        vertical: DesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusExtraLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(color),
          if (status != BadgeStatus.info) const SizedBox(width: DesignTokens.spacing4),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Color color) {
    IconData? iconData;
    switch (status) {
      case BadgeStatus.success:
      case BadgeStatus.verified:
        iconData = Icons.check_circle_outline;
        break;
      case BadgeStatus.warning:
      case BadgeStatus.pending:
        iconData = Icons.hourglass_empty;
        break;
      case BadgeStatus.error:
      case BadgeStatus.critical:
      case BadgeStatus.blocked:
        iconData = Icons.error_outline;
        break;
      case BadgeStatus.info:
        return const SizedBox.shrink();
    }

    return Icon(
      iconData,
      size: 14,
      color: color,
    );
  }
}
