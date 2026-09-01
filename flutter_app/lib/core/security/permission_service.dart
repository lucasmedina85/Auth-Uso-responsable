import 'package:permission_handler/permission_handler.dart';

enum PermissionStatusState { granted, denied, permanentlyDenied }

/// CU-0036: Solicitud de Permisos Dinámicos Android
/// Manages dynamic requests for Camera and Location permissions with rationale.
class PermissionService {
  /// Request camera permission required for DNI and Face Liveness capture
  Future<PermissionStatusState> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return PermissionStatusState.granted;
    }

    final result = await Permission.camera.request();
    if (result.isGranted) {
      return PermissionStatusState.granted;
    } else if (result.isPermanentlyDenied) {
      return PermissionStatusState.permanentlyDenied;
    } else {
      return PermissionStatusState.denied;
    }
  }

  /// Request precise location permission required for audit logging (CU-0020)
  Future<PermissionStatusState> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      return PermissionStatusState.granted;
    }

    final result = await Permission.locationWhenInUse.request();
    if (result.isGranted) {
      return PermissionStatusState.granted;
    } else if (result.isPermanentlyDenied) {
      return PermissionStatusState.permanentlyDenied;
    } else {
      return PermissionStatusState.denied;
    }
  }
}
