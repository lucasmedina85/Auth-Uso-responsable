import 'dart:async';
import 'package:flutter/material.dart';
import '../../logic/secure_storage_service.dart';

class SessionManager extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const SessionManager({
    Key? key,
    required this.child,
    required this.navigatorKey,
  }) : super(key: key);

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  DateTime? _backgroundTime;
  final int _timeoutMinutes = 5;
  final SecureStorageService _secureStorage = SecureStorageService();
  bool _isLoggedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), _logoutDueToInactivity);
  }

  void _resetTimer() {
    if (_isLoggedOut) return;
    _startTimer();
  }

  Future<void> _logoutDueToInactivity() async {
    _isLoggedOut = true;
    _inactivityTimer?.cancel();
    await _secureStorage.logout();
    
    // Navegar a la pantalla de login (o bienvenida) eliminando todo el stack anterior.
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    
    // Mostrar cartel
    final context = widget.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada por inactividad (5 min).'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Pasa a segundo plano
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Vuelve a primer plano
      if (_backgroundTime != null) {
        final difference = DateTime.now().difference(_backgroundTime!);
        if (difference.inMinutes >= _timeoutMinutes) {
          _logoutDueToInactivity();
        } else {
          _resetTimer();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
