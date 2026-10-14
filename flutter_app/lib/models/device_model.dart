class DeviceModel {
  final String id;
  final String deviceHash;
  final String deviceName;
  final String? manufacturer;
  final String? osVersion;
  final String deviceType;
  final String status; // TRUSTED, PENDING, REVOKED
  final bool isCurrent;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final DateTime? trustEvaluatedAt;
  final DateTime? revokedAt;

  DeviceModel({
    required this.id,
    required this.deviceHash,
    required this.deviceName,
    this.manufacturer,
    this.osVersion,
    required this.deviceType,
    required this.status,
    required this.isCurrent,
    this.firstSeenAt,
    this.lastSeenAt,
    this.trustEvaluatedAt,
    this.revokedAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      deviceHash: json['deviceHash'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Dispositivo',
      manufacturer: json['manufacturer'] as String?,
      osVersion: json['osVersion'] as String?,
      deviceType: json['deviceType'] as String? ?? 'MOBILE',
      status: json['status'] as String? ?? 'PENDING',
      isCurrent: json['current'] as bool? ?? json['isCurrent'] as bool? ?? false,
      firstSeenAt: json['firstSeenAt'] != null ? DateTime.tryParse(json['firstSeenAt']) : null,
      lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt']) : null,
      trustEvaluatedAt: json['trustEvaluatedAt'] != null ? DateTime.tryParse(json['trustEvaluatedAt']) : null,
      revokedAt: json['revokedAt'] != null ? DateTime.tryParse(json['revokedAt']) : null,
    );
  }
}

class DeviceAlertModel {
  final String id;
  final String deviceName;
  final String type; // PENDING_APPROVAL, DEVICE_REVOKED
  final String message;
  final DateTime? timestamp;

  DeviceAlertModel({
    required this.id,
    required this.deviceName,
    required this.type,
    required this.message,
    this.timestamp,
  });

  factory DeviceAlertModel.fromJson(Map<String, dynamic> json) {
    return DeviceAlertModel(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String? ?? 'Dispositivo',
      type: json['type'] as String? ?? 'PENDING_APPROVAL',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
    );
  }
}
