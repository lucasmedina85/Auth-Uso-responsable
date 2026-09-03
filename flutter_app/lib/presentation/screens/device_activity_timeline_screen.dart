import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/security_data_service.dart';

class DeviceActivityTimelineScreen extends StatefulWidget {
  const DeviceActivityTimelineScreen({super.key});

  @override
  State<DeviceActivityTimelineScreen> createState() => _DeviceActivityTimelineScreenState();
}

class _DeviceActivityTimelineScreenState extends State<DeviceActivityTimelineScreen> {
  final SecurityDataService _dataService = SecurityDataService();
  late List<SecurityActivity> _activities;
  late TrustedDevice _device;

  String _email = 'Usuario';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _device = args['device'] as TrustedDevice? ?? _dataService.getLatestDevice();
      _email = args['email'] as String? ?? 'Usuario';
    } else if (args is TrustedDevice) {
      _device = args;
    } else {
      _device = _dataService.getLatestDevice();
    }
    _activities = _dataService.getMockActivity(_device.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device Header
            Container(
              padding: const EdgeInsets.all(DesignTokens.spacing24),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(
                    _device.type == 'mobile' ? Icons.smartphone : Icons.computer,
                    size: 32,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _device.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sesión activa: $_email',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spacing4),
                        Text(
                          'Últimas conexiones registradas',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: DesignTokens.spacing16),
            
            // Timeline List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final isLast = index == _activities.length - 1;
                  return _buildTimelineItem(context, _activities[index], isLast);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, SecurityActivity activity, bool isLast) {
    final theme = Theme.of(context);
    
    Color dotColor = theme.primaryColor;
    if (activity.status == EventStatus.blocked || activity.status == EventStatus.error) {
      dotColor = theme.colorScheme.error;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visual
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: DesignTokens.spacing16),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spacing32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${activity.date} — ${activity.time}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing4),
                  Text(
                    activity.event,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activity.status == EventStatus.blocked ? theme.colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing8),
                  Text(
                    activity.device,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Ubicación: ${activity.location}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'IP: ${activity.ip}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
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
