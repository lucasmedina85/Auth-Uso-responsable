import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/totp_service.dart';

class TotpCountdown extends StatelessWidget {
  final int secondsRemaining;

  const TotpCountdown({
    super.key,
    required this.secondsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double progress = secondsRemaining / 30.0;
    
    // Determine color based on time remaining
    Color indicatorColor = theme.primaryColor;
    if (secondsRemaining <= 5) {
      indicatorColor = theme.colorScheme.error;
    } else if (secondsRemaining <= 10) {
      indicatorColor = AppColorsLight.warning;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nuevo código en $secondsRemaining segundos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: indicatorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: indicatorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacing8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: indicatorColor,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

class ApplicationCard extends StatefulWidget {
  final String appName;
  final String deviceName;
  final String applicationId;
  final VoidCallback onCopy;
  final VoidCallback onMenuTap;

  const ApplicationCard({
    super.key,
    required this.appName,
    required this.deviceName,
    required this.applicationId,
    required this.onCopy,
    required this.onMenuTap,
  });

  @override
  State<ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<ApplicationCard> {
  final TotpService _totpService = TotpService();
  bool _copied = false;

  void _handleCopy() {
    widget.onCopy();
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.security, color: theme.primaryColor, size: 24),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.appName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[800],
                      ),
                    ),
                    Text(
                      widget.deviceName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: widget.onMenuTap,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          
          const SizedBox(height: DesignTokens.spacing24),
          
          ValueListenableBuilder<int>(
            valueListenable: _totpService.secondsRemaining,
            builder: (context, seconds, child) {
              final code = _totpService.getCodeFor(widget.applicationId);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing16),
                  TotpCountdown(secondsRemaining: seconds),
                ],
              );
            },
          ),
          
          const SizedBox(height: DesignTokens.spacing24),
          
          InkWell(
            onTap: _handleCopy,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 18,
                    color: _copied ? AppColorsLight.success : theme.primaryColor,
                  ),
                  const SizedBox(width: DesignTokens.spacing8),
                  Text(
                    _copied ? 'Código copiado' : 'Copiar código',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _copied ? AppColorsLight.success : theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
