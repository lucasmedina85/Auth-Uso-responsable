import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

class TotpState {
  final String code;
  final int secondsRemaining;

  TotpState(this.code, this.secondsRemaining);
}

class TotpService {
  static final TotpService _instance = TotpService._internal();
  factory TotpService() => _instance;
  
  Timer? _timer;
  final int period = 30;
  
  // A notifier that emits the state every second for all UI components to sync
  final ValueNotifier<int> _secondsRemaining = ValueNotifier<int>(30);
  ValueNotifier<int> get secondsRemaining => _secondsRemaining;

  // Map to store current mock codes for each app identifier
  final Map<String, String> _currentCodes = {};

  TotpService._internal() {
    _startGlobalTimer();
  }

  void _startGlobalTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final int currentSecond = (now / 1000).floor();
    final int remaining = period - (currentSecond % period);
    
    // When time wraps around, regenerate all mock codes
    if (remaining == period || _currentCodes.isEmpty) {
      _currentCodes.clear(); // Clear so they are regenerated on next request
    }
    
    _secondsRemaining.value = remaining;
  }

  /// Generates a mock 6 digit TOTP code that stays constant for the 30s period
  String getCodeFor(String applicationId) {
    if (!_currentCodes.containsKey(applicationId)) {
      final random = Random();
      final code = (random.nextInt(900000) + 100000).toString(); // 6 digits
      _currentCodes[applicationId] = '${code.substring(0,3)} ${code.substring(3,6)}';
    }
    return _currentCodes[applicationId]!;
  }

  void dispose() {
    _timer?.cancel();
  }
}
