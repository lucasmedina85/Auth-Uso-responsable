import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/security_score.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import '../../models/security_score_model.dart';
import '../../services/device_management_service.dart';
import '../widgets/demo_mode_banner.dart';

/// Screen 39 - User Dashboard
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  String _lastConnection = 'Cargando...';
  SecurityScoreModel? _securityScore;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _loadLastConnectionTime();
    _fetchSecurityScore();
    DeviceManagementService().checkAndNotifyAlerts();
  }

  Future<void> _fetchSecurityScore() async {
    if (!mounted) return;
    final score = await DeviceManagementService().getSecurityScore();
    if (mounted) {
      setState(() {
        _securityScore = score;
      });
    }
  }

  SecurityRiskLevel _mapLevelToRiskLevel(String? level) {
    switch (level?.toUpperCase()) {
      case 'ALTO':
        return SecurityRiskLevel.secure;
      case 'MEDIO':
        return SecurityRiskLevel.medium;
      case 'BAJO':
      default:
        return SecurityRiskLevel.high;
    }
  }

  String _mapLevelToLabel(String? level) {
    switch (level?.toUpperCase()) {
      case 'ALTO':
        return 'Alta Confianza';
      case 'MEDIO':
        return 'Confianza Media';
      case 'BAJO':
      default:
        return 'Baja Confianza';
    }
  }

  void _showScoreBreakdownModal(BuildContext context) {
    final theme = Theme.of(context);
    final score = _securityScore?.score ?? 15;
    final factors = _securityScore?.factors ?? [];
    final levelLabel = _mapLevelToLabel(_securityScore?.level);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLarge)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing24,
                vertical: DesignTokens.spacing20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nivel de Seguridad',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                        ),
                        child: Text(
                          '$score / 100',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spacing8),
                  Text(
                    'Estado actual: $levelLabel. Factores evaluados de forma segura en el servidor.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: DesignTokens.spacing24),
                  Expanded(
                    child: factors.isEmpty
                        ? Center(
                            child: Text(
                              'Sin factores registrados',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: factors.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final factor = factors[index];
                              final isPositive = factor.status == 'POSITIVE';
                              final isNegative = factor.status == 'NEGATIVE';
                              final contribText = factor.contribution >= 0
                                  ? '+${factor.contribution}'
                                  : '${factor.contribution}';

                              Color chipColor = theme.colorScheme.outlineVariant;
                              Color chipTextColor = theme.colorScheme.onSurface;
                              IconData statusIcon = Icons.info_outline;

                              if (isPositive) {
                                chipColor = Colors.green.withOpacity(0.15);
                                chipTextColor = Colors.green.shade800;
                                statusIcon = Icons.check_circle_outline;
                              } else if (isNegative) {
                                chipColor = Colors.red.withOpacity(0.15);
                                chipTextColor = Colors.red.shade800;
                                statusIcon = Icons.remove_circle_outline;
                              }

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  statusIcon,
                                  color: chipTextColor,
                                ),
                                title: Text(
                                  factor.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  factor.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: chipColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    contribText,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: chipTextColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadLastConnectionTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? isoDate = prefs.getString('last_connection_time');
    
    if (isoDate != null) {
      final DateTime date = DateTime.parse(isoDate);
      final String formattedDate = DateFormat("dd/MM/yyyy, hh:mm a").format(date);
      if (mounted) {
        setState(() {
          _lastConnection = 'Última vez: $formattedDate';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _lastConnection = 'Última vez: Nunca';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    final String displayName = (args != null && args is String) ? args : 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AUTHENTICATOR'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: DesignTokens.spacing8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoModeBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    Text(
                      'Hola, $displayName',
                      style: theme.textTheme.headlineMedium,
                    ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Tu identidad está verificada y segura.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Security Score
              SecurityScoreCard(
                score: _securityScore?.score ?? 15,
                level: _mapLevelToRiskLevel(_securityScore?.level),
                customLabel: _securityScore != null ? _mapLevelToLabel(_securityScore!.level) : null,
                onTap: () => _showScoreBreakdownModal(context),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Status Card
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing20),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spacing12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user, color: theme.primaryColor),
                    ),
                    const SizedBox(width: DesignTokens.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _securityScore != null
                                ? _mapLevelToLabel(_securityScore!.level)
                                : 'Calculando nivel...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing4),
                          Text(
                            _lastConnection,
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
              const SizedBox(height: DesignTokens.spacing32),

              // Quick Actions
              Text(
                'Acciones Rápidas',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(context, Icons.fingerprint, 'Verificar\nIdentidad', () {
                      Navigator.pushNamed(context, '/dni_capture');
                    }),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: _buildActionCard(context, Icons.devices, 'Dispositivos\nConfiables', () {
                      Navigator.pushNamed(context, '/trusted_devices');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(context, Icons.apps, 'Aplicaciones\nVinculadas', () {
                      Navigator.pushNamed(context, '/linked_apps_list');
                    }),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: _buildActionCard(context, Icons.link, 'Bitácora\nCriptográfica', () {
                      Navigator.pushNamed(context, '/audit_chain');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(context, Icons.history, 'Actividad\ny Eventos', () {
                      Navigator.pushNamed(context, '/device_activity');
                    }),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: _buildActionCard(context, Icons.hub_outlined, 'Simulador\nTerceros (OAuth)', () {
                      Navigator.pushNamed(context, '/oauth_playground');
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
      bottomNavigationBar: SharedBottomNavBar(
        currentIndex: 0,
        displayName: displayName,
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.primaryColor, size: 28),
            const SizedBox(height: DesignTokens.spacing16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
