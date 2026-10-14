import 'package:flutter/material.dart';
import '../../services/behavioral_biometrics_service.dart';

/// Widget envoltorio para capturar métricas táctiles y tiempos de lectura/permanencia (CU-0035).
///
/// Se aplica de forma transparente sin alterar el comportamiento de los widgets hijos.
class BehaviorTracker extends StatefulWidget {
  final String screenName;
  final Widget child;

  const BehaviorTracker({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<BehaviorTracker> createState() => _BehaviorTrackerState();
}

class _BehaviorTrackerState extends State<BehaviorTracker> {
  final _service = BehavioralBiometricsService();

  @override
  void initState() {
    super.initState();
    _service.recordScreenEntry(widget.screenName);
  }

  @override
  void dispose() {
    _service.recordScreenExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _service.onPointerDown,
      onPointerMove: _service.onPointerMove,
      onPointerUp: _service.onPointerUp,
      child: widget.child,
    );
  }
}
