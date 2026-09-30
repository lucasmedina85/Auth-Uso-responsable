import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../core/network/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const SessionManager({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  DateTime? _backgroundTime;
  int _timeoutMinutes = 5; // Default 5 minutes
  
  bool _isLoggedOut = false;
  StreamSubscription? _authEventSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTtl();
    
    _authEventSub = DioClient.authEventStream.stream.listen((event) {
      if (event == 'CONCURRENT_ACCESS') {
        _logoutDueToConcurrentAccess();
      }
    });
  }
  
  Future<void> _loadTtl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _timeoutMinutes = prefs.getInt('session_ttl') ?? 5;
    });
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _authEventSub?.cancel();
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
  
  Future<void> _logoutDueToConcurrentAccess() async {
    _isLoggedOut = true;
    _inactivityTimer?.cancel();
    await SessionService.clearTokens();
    
    final context = widget.navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Acceso Simultáneo'),
          content: const Text('Hemos detectado un acceso desde otro dispositivo. Tu sesión ha sido cerrada por seguridad.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('OK'),
            )
          ],
        )
      );
    } else {
      widget.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _logoutDueToInactivity() async {
    _isLoggedOut = true;
    _inactivityTimer?.cancel();
    await SessionService.logout();
    
    // Navegar a la pantalla de login (o bienvenida) eliminando todo el stack anterior.
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    
    // Mostrar cartel
    final context = widget.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión cerrada por inactividad ($_timeoutMinutes min).'),
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
      _loadTtl(); // Reload TTL config when resumed in case it was changed
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
