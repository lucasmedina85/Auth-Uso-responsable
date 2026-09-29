import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/database_log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await DatabaseLogService().getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _exportCsv() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/logs_export.csv');
      
      String csvContent = "ID,Fecha,Tipo,Detalle,Estado\n";
      for (var log in _logs) {
        csvContent += "${log['id']},${log['timestamp']},${log['eventType']},${log['details']},${log['status']}\n";
      }
      
      await file.writeAsString(csvContent);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logs exportados exitosamente a ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logs de Sistema',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar a CSV',
            onPressed: _logs.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _logs.isEmpty
            ? const Center(child: Text("No hay registros en el log local."))
            : ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final isSuccess = log['status'] == 'SUCCESS' || log['status'] == 'APPROVED';
                  return ListTile(
                    leading: Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                    title: Text('${log['eventType']} - ${log['status']}'),
                    subtitle: Text('${log['timestamp']}\n${log['details']}'),
                    isThreeLine: true,
                  );
                },
              ),
    );
  }
}
