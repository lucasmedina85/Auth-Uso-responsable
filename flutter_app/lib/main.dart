import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/device_security_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/terms_screen.dart';
import 'presentation/screens/privacy_screen.dart';
import 'presentation/screens/registration_success_screen.dart';
import 'presentation/screens/permission_screen.dart';
import 'presentation/screens/dni_capture_screen.dart';
import 'presentation/screens/face_liveness_screen.dart';
import 'presentation/screens/biometric_fingerprint_screen.dart';
import 'presentation/screens/authentication_success_screen.dart';
import 'presentation/screens/user_dashboard_screen.dart';
import 'presentation/screens/logs_screen.dart';
import 'presentation/screens/add_application_screen.dart';
import 'presentation/screens/application_qr_screen.dart';
import 'presentation/screens/application_linked_screen.dart';
import 'presentation/screens/authenticator_dashboard_screen.dart';
import 'presentation/screens/device_details_screen.dart';
import 'presentation/screens/security_history_screen.dart';
import 'presentation/screens/trusted_devices_screen.dart';
import 'presentation/screens/device_activity_timeline_screen.dart';
import 'presentation/screens/change_password_screen.dart';
void main() {
  runApp(const AuthenticatorApp());
}

/// Principal Application Authenticator
class AuthenticatorApp extends StatelessWidget {
  const AuthenticatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUTHENTICATOR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/device_security': (context) => const DeviceSecurityScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/terms': (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/registration_success': (context) => const RegistrationSuccessScreen(),
        '/permissions': (context) => const PermissionScreen(),
        '/dni_capture': (context) => DniCaptureScreenFlutter(
          onComplete: (f, b) {
            // Navigate to face liveness when DNI is done
            Navigator.pushReplacementNamed(context, '/face_liveness');
          },
          onManualFallback: () {
            // Fallback action
          },
        ),
        '/face_liveness': (context) => const FaceLivenessScreen(),
        '/fingerprint': (context) => const BiometricFingerprintScreen(),
        '/authentication_success': (context) => const AuthenticationSuccessScreen(),
        '/dashboard': (context) => const UserDashboardScreen(),
        '/add_application': (context) => const AddApplicationScreen(),
        '/application_qr': (context) => const ApplicationQrScreen(),
        '/application_linked': (context) => const ApplicationLinkedScreen(),
        '/authenticator_dashboard': (context) => const AuthenticatorDashboardScreen(),
        '/device_details': (context) => const DeviceDetailsScreen(),
        '/security_history': (context) => const SecurityHistoryScreen(),
        '/trusted_devices': (context) => const TrustedDevicesScreen(),
        '/device_activity': (context) => const DeviceActivityTimelineScreen(),
        '/change_password': (context) => const ChangePasswordScreen(),
        
        // Legacy routes kept for compatibility
        '/logs': (context) => const LogsScreen(),
      },
    );
  }
}
