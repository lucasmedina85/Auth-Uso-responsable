import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

enum SecurityRiskLevel {
  low,
  secure,
  medium,
  high,
  critical,
}

class SecurityScoreCard extends StatelessWidget {
  final int score; // 0 to 100
  final SecurityRiskLevel level;

  const SecurityScoreCard({
    super.key,
    required this.score,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color getColor() {
      switch (level) {
        case SecurityRiskLevel.low:
          return isDark ? AppColorsDark.success : AppColorsLight.success;
        case SecurityRiskLevel.secure:
          return isDark ? AppColorsDark.primary : AppColorsLight.primary;
        case SecurityRiskLevel.medium:
          return isDark ? AppColorsDark.warning : AppColorsLight.warning;
        case SecurityRiskLevel.high:
          return isDark ? AppColorsDark.error : AppColorsLight.error;
        case SecurityRiskLevel.critical:
          return isDark ? AppColorsDark.critical : AppColorsLight.critical;
      }
    }

    String getLabel() {
      switch (level) {
        case SecurityRiskLevel.low: return "Low Risk";
        case SecurityRiskLevel.secure: return "Secure";
        case SecurityRiskLevel.medium: return "Medium Risk";
        case SecurityRiskLevel.high: return "High Risk";
        case SecurityRiskLevel.critical: return "Critical Risk";
      }
    }

    final color = getColor();

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          // Score Circle
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  score.toString(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.spacing24),
          // Text Data
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Security Score",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing4),
                Row(
                  children: [
                    Icon(Icons.shield_rounded, color: color, size: 20),
                    const SizedBox(width: DesignTokens.spacing8),
                    Text(
                      getLabel(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
