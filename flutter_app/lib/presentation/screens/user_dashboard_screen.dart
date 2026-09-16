import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/security_score.dart';
import '../widgets/shared_bottom_nav_bar.dart';

/// Screen 39 - User Dashboard
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _currentIndex = 0;
  String _lastConnection = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadLastConnectionTime();
  }

  Future<void> _loadLastConnectionTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? isoDate = prefs.getString('last_connection_time');
    
    if (isoDate != null) {
      final DateTime date = DateTime.parse(isoDate);
      final String formattedDate = DateFormat("dd/MM/yyyy, hh:mm a").format(date);
      setState(() {
        _lastConnection = 'Última vez: $formattedDate';
      });
    } else {
      setState(() {
        _lastConnection = 'Última vez: Nunca';
      });
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
              const SecurityScoreCard(
                score: 98,
                level: SecurityRiskLevel.secure,
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
                            'Alta Confianza',
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
            ],
          ),
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
