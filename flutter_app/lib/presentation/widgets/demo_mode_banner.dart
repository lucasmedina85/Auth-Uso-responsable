import 'package:flutter/material.dart';
import '../../services/demo_mode_service.dart';

/// Banner interactivo visible en modo local/demo que permite alternar los escenarios de prueba.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final demoService = DemoModeService();
    if (!demoService.isDemoModeEnabled) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DemoScenario>(
      valueListenable: demoService.currentScenarioNotifier,
      builder: (context, currentScenario, _) {
        return Container(
          width: double.infinity,
          color: Colors.amber.shade900.withOpacity(0.92),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.science_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'MODO DEMO – datos locales y simulados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showScenarioSelector(context, demoService),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentScenario.shortLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showScenarioSelector(BuildContext context, DemoModeService demoService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    const Text(
                      'Selector de Escenario (Modo Demo)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permite forzar el comportamiento de la validación biométrica para demostrar cada flujo ante el evaluador.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const Divider(height: 24),
                ...DemoScenario.values.map((scenario) {
                  final isSelected = demoService.currentScenario == scenario;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.amber.shade800 : Colors.grey,
                    ),
                    title: Text(
                      scenario.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.amber.shade900 : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      demoService.setScenario(scenario);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Escenario activado: ${scenario.displayName}'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.blueGrey.shade800,
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}
