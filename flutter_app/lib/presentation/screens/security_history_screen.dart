import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/security_data_service.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

class SecurityHistoryScreen extends StatefulWidget {
  const SecurityHistoryScreen({super.key});

  @override
  State<SecurityHistoryScreen> createState() => _SecurityHistoryScreenState();
}

class _SecurityHistoryScreenState extends State<SecurityHistoryScreen> {
  final SecurityDataService _dataService = SecurityDataService();
  late List<SecurityLog> _logs;
  List<SecurityLog> _filteredLogs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logs = _dataService.getMockLogs();
    _filteredLogs = List.from(_logs);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLogs = _logs.where((log) {
        return log.eventType.toLowerCase().contains(query) ||
               log.device.toLowerCase().contains(query) ||
               log.ip.contains(query) ||
               log.id.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _exportCsv() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar historial'),
        content: const Text('Se generará un archivo CSV con los eventos de seguridad seleccionados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _dataService.exportCsvMock(context);
            },
            child: const Text('Exportar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Seguridad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Description
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spacing20),
              child: Text(
                'Registro de actividad y eventos de seguridad de tu cuenta',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            
            // Summary Cards (Horizontal Scrollable)
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                children: [
                  _buildSummaryCard(context, 'Eventos', '${_logs.length}'),
                  _buildSummaryCard(context, 'Exitosas', '${_logs.where((e) => e.status == EventStatus.success).length}'),
                  _buildSummaryCard(context, 'Dispositivos', '3'),
                  _buildSummaryCard(context, 'Última Actividad', 'Hoy, 14:32'),
                ],
              ),
            ),
            
            const SizedBox(height: DesignTokens.spacing16),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
              child: StandardTextField(
                label: 'Buscar actividad...',
                hint: 'Buscar por evento, IP o ID',
                controller: _searchController,
              ),
            ),
            
            const SizedBox(height: DesignTokens.spacing16),
            
            // Logs List
            Expanded(
              child: _filteredLogs.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.all(DesignTokens.spacing20),
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        return _buildLogCard(context, _filteredLogs[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: DesignTokens.spacing12),
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, SecurityLog log) {
    final theme = Theme.of(context);
    
    IconData icon;
    Color statusColor;
    switch (log.status) {
      case EventStatus.success:
        icon = Icons.check_circle_outline;
        statusColor = AppColorsLight.success;
        break;
      case EventStatus.warning:
        icon = Icons.warning_amber_rounded;
        statusColor = AppColorsLight.warning;
        break;
      case EventStatus.error:
      case EventStatus.blocked:
        icon = Icons.block;
        statusColor = theme.colorScheme.error;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showLogDetails(context, log),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: statusColor, size: 28),
              const SizedBox(width: DesignTokens.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            log.eventType,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          log.time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spacing4),
                    Text(
                      '${log.device} • ${log.ip}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.result,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'No encontramos eventos que coincidan',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(BuildContext context, SecurityLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLarge)),
      ),
      builder: (context) => _LogDetailSheet(log: log),
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  final SecurityLog log;

  const _LogDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return SafeArea(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(DesignTokens.spacing24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              Text(
                'Detalle del evento',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              
              _buildDetailRow(theme, 'Fecha', log.date),
              _buildDetailRow(theme, 'Hora', log.time),
              _buildDetailRow(theme, 'Evento', log.eventType),
              _buildDetailRow(theme, 'Resultado', log.result),
              _buildDetailRow(theme, 'Dispositivo', log.device),
              _buildDetailRow(theme, 'Sistema', log.os),
              _buildDetailRow(theme, 'Dirección IP', log.ip),
              _buildDetailRow(theme, 'Ubicación', log.location),
              _buildDetailRow(theme, 'Método', log.authMethod),
              _buildDetailRow(theme, 'Identificador', log.id),
              
              if (log.evidenceImages.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spacing32),
                Text(
                  'Evidencias de validación',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  'Las evidencias de identidad están protegidas y disponibles únicamente para fines de seguridad y auditoría.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing16),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: log.evidenceImages.length,
                    itemBuilder: (context, index) {
                      final imagePath = log.evidenceImages[index];
                      final isFront = index == 0;
                      return GestureDetector(
                        onTap: () {
                          _showImageViewer(context, imagePath, isFront ? 'Documento — Frente' : 'Documento — Dorso');
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: DesignTokens.spacing16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, size: 40, color: theme.primaryColor),
                              const SizedBox(height: 8),
                              Text(
                                isFront ? 'Frente' : 'Dorso',
                                style: theme.textTheme.labelMedium,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spacing40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageViewer(BuildContext context, String imagePath, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Container(
                width: double.infinity,
                height: 300,
                color: Colors.grey.shade900,
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
